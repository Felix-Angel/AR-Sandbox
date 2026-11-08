using System;
using System.IO;
using System.Linq;
using System.Net.WebSockets;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Microsoft.Kinect;

namespace ArSandbox.KinectDepthPreview
{
    public partial class MainWindow : Window
    {
        private const int BytesPorPixel = 4;
        private const string UrlCapturaBackend = "ws://127.0.0.1:8000/ws/sensor/captura";
        private KinectSensor _sensor;
        private WriteableBitmap _bitmap;
        private DepthImagePixel[] _pixelesProfundidad;
        private byte[] _pixelesColor;
        private ClientWebSocket _clienteBackend;
        private readonly SemaphoreSlim _semaforoEnvio = new SemaphoreSlim(1, 1);
        private readonly CancellationTokenSource _cancelacionEnvio = new CancellationTokenSource();
        private readonly DispatcherTimer _temporizadorReconexion;
        private DateTime _inicioConteoFps = DateTime.UtcNow;
        private int _fotogramasEnIntervalo;
        private uint _idFotograma;
        private bool _conectandoBackend;
        private volatile bool _capturaActiva = true;
        private bool _cerrando;

        public MainWindow()
        {
            InitializeComponent();
            _temporizadorReconexion = new DispatcherTimer
            {
                Interval = TimeSpan.FromSeconds(3),
            };
            _temporizadorReconexion.Tick += async (sender, args) => await ConectarBackendAsync();
            Loaded += IniciarSensor;
            Closed += DetenerSensor;
        }

        private async void IniciarSensor(object sender, RoutedEventArgs e)
        {
            _sensor = KinectSensor.KinectSensors.FirstOrDefault(
                sensor => sensor.Status == KinectStatus.Connected);

            if (_sensor == null)
            {
                EstadoSensor.Text = "Kinect no detectado. Revisa el adaptador de corriente, USB y el controlador Kinect v1.";
                return;
            }

            try
            {
                _sensor.DepthStream.Enable(DepthImageFormat.Resolution640x480Fps30);
                int ancho = _sensor.DepthStream.FrameWidth;
                int alto = _sensor.DepthStream.FrameHeight;
                _pixelesProfundidad = new DepthImagePixel[ancho * alto];
                _pixelesColor = new byte[ancho * alto * BytesPorPixel];
                _bitmap = new WriteableBitmap(ancho, alto, 96, 96, PixelFormats.Bgra32, null);
                VistaProfundidad.Source = _bitmap;

                _sensor.DepthFrameReady += AlRecibirFotograma;
                _sensor.Start();
                EstadoSensor.Text = "Kinect conectado; esperando el primer fotograma de profundidad...";
                _temporizadorReconexion.Start();
                await ConectarBackendAsync();
            }
            catch (Exception error)
            {
                EstadoSensor.Text = "No se pudo iniciar el sensor: " + error.Message;
                if (_sensor != null)
                {
                    _sensor.DepthFrameReady -= AlRecibirFotograma;
                    if (_sensor.IsRunning) _sensor.Stop();
                }
                _sensor = null;
            }
        }

        private void AlRecibirFotograma(object sender, DepthImageFrameReadyEventArgs e)
        {
            using (DepthImageFrame fotograma = e.OpenDepthImageFrame())
            {
                if (fotograma == null || _bitmap == null) return;

                fotograma.CopyDepthImagePixelDataTo(_pixelesProfundidad);
                int minimo = int.MaxValue;
                int maximo = 0;
                int pixelesValidos = 0;

                foreach (DepthImagePixel pixel in _pixelesProfundidad)
                {
                    if (pixel.Depth <= 0) continue;
                    minimo = Math.Min(minimo, pixel.Depth);
                    maximo = Math.Max(maximo, pixel.Depth);
                    pixelesValidos++;
                }

                int rango = Math.Max(1, maximo - minimo);
                for (int indice = 0; indice < _pixelesProfundidad.Length; indice++)
                {
                    int profundidad = _pixelesProfundidad[indice].Depth;
                    byte intensidad = profundidad <= 0
                        ? (byte)0
                        : (byte)Math.Max(0, Math.Min(255, 255 - ((profundidad - minimo) * 255 / rango)));
                    int offset = indice * BytesPorPixel;
                    _pixelesColor[offset] = intensidad;
                    _pixelesColor[offset + 1] = intensidad;
                    _pixelesColor[offset + 2] = intensidad;
                    _pixelesColor[offset + 3] = 255;
                }

                int ancho = fotograma.Width;
                int alto = fotograma.Height;
                int profundidadMinima = pixelesValidos == 0 ? 0 : minimo;
                int profundidadMaxima = maximo;
                IntentarEnviarFotograma(ancho, alto, profundidadMinima, profundidadMaxima, pixelesValidos);
                DateTime ahora = DateTime.UtcNow;
                _fotogramasEnIntervalo++;
                TimeSpan intervalo = ahora - _inicioConteoFps;
                bool actualizarEstado = intervalo.TotalSeconds >= 1;
                double fps = actualizarEstado ? _fotogramasEnIntervalo / intervalo.TotalSeconds : 0;
                if (actualizarEstado)
                {
                    _fotogramasEnIntervalo = 0;
                    _inicioConteoFps = ahora;
                }

                Dispatcher.Invoke(() =>
                {
                    _bitmap.WritePixels(
                        new Int32Rect(0, 0, ancho, alto),
                        _pixelesColor,
                        ancho * BytesPorPixel,
                        0);

                    if (actualizarEstado)
                    {
                        EstadoSensor.Text = string.Format(
                            "Kinect conectado · {0:F1} FPS · profundidad válida: {1}–{2} mm · píxeles: {3:N0}/{4:N0}",
                            fps,
                            profundidadMinima,
                            profundidadMaxima,
                            pixelesValidos,
                            _pixelesProfundidad.Length);
                    }
                });
            }
        }

        private async Task ConectarBackendAsync()
        {
            if (_cerrando || _conectandoBackend || _clienteBackend?.State == WebSocketState.Open) return;

            _conectandoBackend = true;
            var cliente = new ClientWebSocket();
            try
            {
                using (var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(3)))
                {
                    await cliente.ConnectAsync(new Uri(UrlCapturaBackend), timeout.Token);
                }

                if (_cerrando)
                {
                    cliente.Dispose();
                    return;
                }

                _clienteBackend?.Dispose();
                _clienteBackend = cliente;
                EstadoBackend.Text = "FastAPI conectado · enviando profundidad en tiempo real.";
                _temporizadorReconexion.Stop();
                _ = EscucharComandosBackendAsync(cliente);
            }
            catch
            {
                cliente.Dispose();
                if (!_cerrando)
                {
                    EstadoBackend.Text = "FastAPI no disponible · vista local activa; reintentando conexión.";
                    if (!_temporizadorReconexion.IsEnabled) _temporizadorReconexion.Start();
                }
            }
            finally
            {
                _conectandoBackend = false;
            }
        }

        private async Task EscucharComandosBackendAsync(ClientWebSocket cliente)
        {
            var buffer = new byte[256];
            try
            {
                while (!_cerrando && cliente.State == WebSocketState.Open)
                {
                    var resultado = await cliente.ReceiveAsync(
                        new ArraySegment<byte>(buffer),
                        _cancelacionEnvio.Token);
                    if (resultado.MessageType == WebSocketMessageType.Close) break;
                    if (resultado.MessageType != WebSocketMessageType.Text) continue;

                    var comando = System.Text.Encoding.UTF8.GetString(buffer, 0, resultado.Count);
                    if (comando.Contains("\"captura\":false"))
                    {
                        AplicarEstadoCaptura(false);
                    }
                    else if (comando.Contains("\"captura\":true"))
                    {
                        AplicarEstadoCaptura(true);
                    }
                }
            }
            catch
            {
                // El bucle de envío detecta y recupera la conexión cuando sea necesario.
            }
        }

        private void AplicarEstadoCaptura(bool activa)
        {
            _capturaActiva = activa;
            Dispatcher.BeginInvoke(new Action(() =>
            {
                if (_sensor == null) return;
                try
                {
                    if (activa)
                    {
                        _sensor.DepthStream.Enable(DepthImageFormat.Resolution640x480Fps30);
                        EstadoBackend.Text = "FastAPI conectado · enviando profundidad en tiempo real.";
                    }
                    else
                    {
                        _sensor.DepthStream.Disable();
                        EstadoBackend.Text = "FastAPI conectado · captura pausada desde la aplicación.";
                    }
                }
                catch (Exception error)
                {
                    EstadoBackend.Text = "No se pudo cambiar la captura: " + error.Message;
                }
            }));
        }

        private void IntentarEnviarFotograma(
            int ancho,
            int alto,
            int profundidadMinima,
            int profundidadMaxima,
            int pixelesValidos)
        {
            ClientWebSocket cliente = _clienteBackend;
            if (!_capturaActiva || cliente == null || cliente.State != WebSocketState.Open || !_semaforoEnvio.Wait(0)) return;

            byte[] paquete;
            try
            {
                paquete = CrearPaqueteProfundidad(
                    ancho,
                    alto,
                    profundidadMinima,
                    profundidadMaxima,
                    pixelesValidos);
            }
            catch
            {
                _semaforoEnvio.Release();
                return;
            }

            _ = EnviarPaqueteAsync(cliente, paquete);
        }

        private byte[] CrearPaqueteProfundidad(
            int ancho,
            int alto,
            int profundidadMinima,
            int profundidadMaxima,
            int pixelesValidos)
        {
            using (var memoria = new MemoryStream(30 + _pixelesProfundidad.Length * 2))
            using (var escritor = new BinaryWriter(memoria))
            {
                escritor.Write(new byte[] { (byte)'A', (byte)'R', (byte)'K', (byte)'D' });
                escritor.Write((byte)1);
                escritor.Write((byte)0);
                escritor.Write((ushort)ancho);
                escritor.Write((ushort)alto);
                escritor.Write(unchecked(++_idFotograma));
                escritor.Write(unchecked((ulong)DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()));
                escritor.Write((ushort)profundidadMinima);
                escritor.Write((ushort)profundidadMaxima);
                escritor.Write((uint)pixelesValidos);

                foreach (DepthImagePixel pixel in _pixelesProfundidad)
                {
                    int profundidad = Math.Max(0, Math.Min(ushort.MaxValue, pixel.Depth));
                    escritor.Write((ushort)profundidad);
                }

                escritor.Flush();
                return memoria.ToArray();
            }
        }

        private async Task EnviarPaqueteAsync(ClientWebSocket cliente, byte[] paquete)
        {
            try
            {
                await cliente.SendAsync(
                    new ArraySegment<byte>(paquete),
                    WebSocketMessageType.Binary,
                    true,
                    _cancelacionEnvio.Token);
            }
            catch
            {
                if (ReferenceEquals(_clienteBackend, cliente))
                {
                    _clienteBackend = null;
                    cliente.Dispose();
                    if (!_cerrando)
                    {
                        Dispatcher.BeginInvoke(new Action(() =>
                        {
                            EstadoBackend.Text = "Se perdió FastAPI · vista local activa; reintentando conexión.";
                            if (!_temporizadorReconexion.IsEnabled) _temporizadorReconexion.Start();
                        }));
                    }
                }
            }
            finally
            {
                _semaforoEnvio.Release();
            }
        }

        private void DetenerSensor(object sender, EventArgs e)
        {
            _cerrando = true;
            _temporizadorReconexion.Stop();
            _cancelacionEnvio.Cancel();
            _clienteBackend?.Dispose();
            _clienteBackend = null;

            if (_sensor == null) return;

            _sensor.DepthFrameReady -= AlRecibirFotograma;
            if (_sensor.IsRunning) _sensor.Stop();
            _sensor = null;
        }
    }
}
