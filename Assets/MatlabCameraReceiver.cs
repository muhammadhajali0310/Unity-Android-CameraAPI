using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using UnityEngine;

public class MatlabCameraReceiver : MonoBehaviour
{
    [Header("Network Settings")]
    public int listenPort = 8052;
    public string listenIP = "127.0.0.1";

    [Header("Display Settings")]
    public Renderer targetRenderer; // Assign your plane/quad renderer
    public bool flipVertically = true;
    public bool showDebugInfo = true;

    [Header("Performance")]
    [Range(1, 10)]
    public int textureUpdateInterval = 1; // Update every N frames received
    public bool enableFrameSkipping = true; // Skip frames to maintain real-time
    public int maxBufferedFrames = 2; // Maximum frames to buffer before dropping
    public bool showLatencyInfo = true;

    // Private variables
    private TcpListener tcpListener;
    private Thread tcpListenerThread;
    private bool isListening = false;
    private bool isReceiving = false;

    // Image data
    private int imageWidth = 960;
    private int imageHeight = 540;
    private int imageChannels = 3;
    private byte[] imageData;
    private Texture2D cameraTexture;

    // Threading and synchronization
    private readonly object textureLock = new object();
    private bool newDataAvailable = false;
    private byte[] textureBuffer;
    private bool needsTextureInit = false;

    // Performance monitoring
    private float lastFrameTime;
    private float lastFpsUpdateTime;
    private int frameCount = 0;
    private int droppedFrames = 0;
    private float fps = 0f;
    private int bytesReceived = 0;
    private System.Diagnostics.Stopwatch latencyStopwatch = new System.Diagnostics.Stopwatch();
    private float averageLatency = 0f;
    private Queue<float> latencyHistory = new Queue<float>();

    // Frame dropping for real-time performance
    private int bufferedFrameCount = 0;
    private readonly object frameCountLock = new object();

    void Start()
    {
        Debug.Log("Starting Matlab Camera Feed Receiver...");
        lastFpsUpdateTime = Time.time;
        StartTcpListener();
    }

    void Update()
    {
        // Initialize texture if needed (on main thread)
        if (needsTextureInit)
        {
            InitializeCameraTexture();
            needsTextureInit = false;
        }

        // Update texture on main thread when new data is available
        // Remove frame rate limiting for real-time performance
        if (newDataAvailable)
        {
            UpdateCameraTexture();
            newDataAvailable = false;
            lastFrameTime = Time.time;
            frameCount++; // Count frames when they're actually displayed

            // Update latency measurement
            if (latencyStopwatch.IsRunning)
            {
                float currentLatency = latencyStopwatch.ElapsedMilliseconds;
                latencyHistory.Enqueue(currentLatency);

                // Keep only last 30 measurements for rolling average
                while (latencyHistory.Count > 30)
                {
                    latencyHistory.Dequeue();
                }

                // Calculate average latency
                float sum = 0f;
                foreach (float latency in latencyHistory)
                {
                    sum += latency;
                }
                averageLatency = sum / latencyHistory.Count;

                latencyStopwatch.Reset();
            }
        }

        // Update FPS counter
        if (showDebugInfo && Time.time - lastFpsUpdateTime > 1f)
        {
            fps = frameCount / (Time.time - lastFpsUpdateTime);
            frameCount = 0;
            lastFpsUpdateTime = Time.time;
        }
    }

    void OnGUI()
    {
        if (showDebugInfo)
        {
            GUILayout.BeginArea(new Rect(10, 10, 350, 250));
            GUILayout.Label($"=== MATLAB RGB FEED ===");
            GUILayout.Label($"Status: {(isReceiving ? "RECEIVING" : "WAITING")}");
            GUILayout.Label($"Resolution: {imageWidth}x{imageHeight}");
            GUILayout.Label($"Channels: {imageChannels} (RGB)");
            GUILayout.Label($"FPS: {fps:F1}");
            GUILayout.Label($"Data Rate: {bytesReceived / 1024f / 1024f:F2} MB/s");
            GUILayout.Label($"Port: {listenPort}");
            GUILayout.Label($"Filter: Active orientation filtering");

            if (showLatencyInfo)
            {
                GUILayout.Label($"--- LATENCY INFO ---");
                GUILayout.Label($"Avg Latency: {averageLatency:F1} ms");
                GUILayout.Label($"Dropped Frames: {droppedFrames}");
                GUILayout.Label($"Buffered: {bufferedFrameCount}");
                GUILayout.Label($"Frame Skip: {(enableFrameSkipping ? "ON" : "OFF")}");
            }
            GUILayout.EndArea();
        }
    }

    void StartTcpListener()
    {
        try
        {
            IPAddress ipAddress = IPAddress.Parse(listenIP);
            tcpListener = new TcpListener(ipAddress, listenPort);
            tcpListenerThread = new Thread(new ThreadStart(ListenForClients));
            tcpListenerThread.IsBackground = true;
            tcpListenerThread.Start();
            Debug.Log($"TCP Listener started on {listenIP}:{listenPort}");
        }
        catch (Exception e)
        {
            Debug.LogError($"Failed to start TCP listener: {e.Message}");
        }
    }

    void ListenForClients()
    {
        tcpListener.Start();
        isListening = true;
        Debug.Log("Waiting for MATLAB connection...");

        while (isListening)
        {
            try
            {
                using (TcpClient client = tcpListener.AcceptTcpClient())
                {
                    Debug.Log("MATLAB connected!");
                    isReceiving = true;
                    HandleClientCommunication(client);
                }
            }
            catch (Exception e)
            {
                if (isListening)
                {
                    Debug.LogError($"TCP Listener error: {e.Message}");
                }
            }
            finally
            {
                isReceiving = false;
            }
        }
    }

    void HandleClientCommunication(TcpClient client)
    {
        NetworkStream stream = client.GetStream();

        try
        {
            // Receive metadata (width and height)
            byte[] metadataBuffer = new byte[8];
            int metadataBytesRead = 0;
            while (metadataBytesRead < 8)
            {
                int bytesRead = stream.Read(metadataBuffer, metadataBytesRead, 8 - metadataBytesRead);
                if (bytesRead == 0) throw new Exception("Connection closed during metadata read");
                metadataBytesRead += bytesRead;
            }

            imageWidth = BitConverter.ToInt32(metadataBuffer, 0);
            imageHeight = BitConverter.ToInt32(metadataBuffer, 4);

            Debug.Log($"Received metadata: {imageWidth}x{imageHeight}");

            // Signal main thread to initialize texture
            needsTextureInit = true;

            // Wait for texture initialization to complete
            while (needsTextureInit && isListening)
            {
                Thread.Sleep(10);
            }

            // Receive image frames
            while (client.Connected && isListening)
            {
                ReceiveImageFrame(stream);
                frameCount++;
            }
        }
        catch (Exception e)
        {
            Debug.LogError($"Communication error: {e.Message}");
        }
        finally
        {
            Debug.Log("MATLAB disconnected.");
        }
    }

    void ReceiveImageFrame(NetworkStream stream)
    {
        try
        {
            // Start latency measurement
            latencyStopwatch.Start();

            // Read data size first
            byte[] sizeBuffer = new byte[4];
            int sizeBytesRead = 0;
            while (sizeBytesRead < 4)
            {
                int bytesRead = stream.Read(sizeBuffer, sizeBytesRead, 4 - sizeBytesRead);
                if (bytesRead == 0) throw new Exception("Connection closed during size read");
                sizeBytesRead += bytesRead;
            }

            int dataSize = BitConverter.ToInt32(sizeBuffer, 0);
            int expectedSize = imageWidth * imageHeight * imageChannels;

            if (dataSize != expectedSize)
            {
                Debug.LogWarning($"Unexpected data size: {dataSize}, expected: {expectedSize}");
                return;
            }

            // Check if we should drop this frame for real-time performance
            lock (frameCountLock)
            {
                if (enableFrameSkipping && bufferedFrameCount >= maxBufferedFrames)
                {
                    // Skip this frame by reading and discarding the data
                    byte[] discardBuffer = new byte[8192]; // 8KB chunks
                    int remainingBytes = dataSize;
                    while (remainingBytes > 0)
                    {
                        int chunkSize = Math.Min(discardBuffer.Length, remainingBytes);
                        int bytesRead = stream.Read(discardBuffer, 0, chunkSize);
                        if (bytesRead == 0) throw new Exception("Connection closed during frame skip");
                        remainingBytes -= bytesRead;
                    }

                    droppedFrames++;
                    latencyStopwatch.Reset();
                    return; // Skip processing this frame
                }

                bufferedFrameCount++;
            }

            // Read image data
            if (imageData == null || imageData.Length != dataSize)
            {
                imageData = new byte[dataSize];
            }

            int totalBytesRead = 0;
            while (totalBytesRead < dataSize)
            {
                int bytesRead = stream.Read(imageData, totalBytesRead, dataSize - totalBytesRead);
                if (bytesRead == 0) throw new Exception("Connection closed during image read");
                totalBytesRead += bytesRead;
            }

            bytesReceived += totalBytesRead;

            // Process RGB data and prepare for texture update
            ProcessRGBData();
        }
        catch (Exception e)
        {
            Debug.LogError($"Frame receive error: {e.Message}");
            throw;
        }
    }

    void ProcessRGBData()
    {
        try
        {
            // Convert from MATLAB format [R,G,B,R,G,B...] to Unity format
            int pixelCount = imageWidth * imageHeight;

            lock (textureLock)
            {
                if (textureBuffer == null || textureBuffer.Length != pixelCount * 4)
                {
                    textureBuffer = new byte[pixelCount * 4]; // RGBA format for Unity
                }

                // Convert RGB to RGBA and handle coordinate system differences
                for (int i = 0; i < pixelCount; i++)
                {
                    int srcIndex = i * 3;
                    int dstIndex = i * 4;

                    // Copy RGB and add full alpha
                    textureBuffer[dstIndex] = imageData[srcIndex];         // R
                    textureBuffer[dstIndex + 1] = imageData[srcIndex + 1]; // G
                    textureBuffer[dstIndex + 2] = imageData[srcIndex + 2]; // B
                    textureBuffer[dstIndex + 3] = 255;                     // A (full opacity)
                }

                newDataAvailable = true;
            }
        }
        catch (Exception e)
        {
            Debug.LogError($"RGB processing error: {e.Message}");
        }
    }

    void InitializeCameraTexture()
    {
        if (cameraTexture != null)
        {
            DestroyImmediate(cameraTexture);
        }

        cameraTexture = new Texture2D(imageWidth, imageHeight, TextureFormat.RGBA32, false);
        cameraTexture.wrapMode = TextureWrapMode.Clamp;
        cameraTexture.filterMode = FilterMode.Bilinear;

        if (targetRenderer != null)
        {
            targetRenderer.material.mainTexture = cameraTexture;
            Debug.Log($"Camera texture initialized: {imageWidth}x{imageHeight}");
        }
        else
        {
            Debug.LogWarning("No target renderer assigned!");
        }
    }

    void UpdateCameraTexture()
    {
        if (cameraTexture == null) return;

        lock (textureLock)
        {
            if (textureBuffer != null)
            {
                try
                {
                    // Load raw texture data
                    cameraTexture.LoadRawTextureData(textureBuffer);

                    // Flip vertically if needed (MATLAB vs Unity coordinate systems)
                    if (flipVertically)
                    {
                        FlipTextureVertically();
                    }

                    cameraTexture.Apply();

                    // Decrease buffered frame count
                    lock (frameCountLock)
                    {
                        bufferedFrameCount = Math.Max(0, bufferedFrameCount - 1);
                    }
                }
                catch (Exception e)
                {
                    Debug.LogError($"Texture update error: {e.Message}");
                }
            }
        }
    }

    void FlipTextureVertically()
    {
        Color32[] pixels = cameraTexture.GetPixels32();
        Color32[] flippedPixels = new Color32[pixels.Length];

        for (int y = 0; y < imageHeight; y++)
        {
            for (int x = 0; x < imageWidth; x++)
            {
                int originalIndex = y * imageWidth + x;
                int flippedIndex = (imageHeight - 1 - y) * imageWidth + x;
                flippedPixels[flippedIndex] = pixels[originalIndex];
            }
        }

        cameraTexture.SetPixels32(flippedPixels);
    }

    void OnApplicationQuit()
    {
        StopTcpListener();
    }

    void OnDestroy()
    {
        StopTcpListener();

        if (cameraTexture != null)
        {
            DestroyImmediate(cameraTexture);
        }
    }

    void StopTcpListener()
    {
        isListening = false;
        isReceiving = false;

        if (tcpListener != null)
        {
            tcpListener.Stop();
        }

        if (tcpListenerThread != null && tcpListenerThread.IsAlive)
        {
            tcpListenerThread.Join(1000); // Wait up to 1 second
            if (tcpListenerThread.IsAlive)
            {
                tcpListenerThread.Abort();
            }
        }

        Debug.Log("TCP Listener stopped.");
    }
}

// Simple main thread dispatcher that doesn't use FindObjectOfType
public class UnityMainThreadDispatcher : MonoBehaviour
{
    private static UnityMainThreadDispatcher _instance;
    private readonly Queue<System.Action> _executionQueue = new Queue<System.Action>();

    void Awake()
    {
        if (_instance == null)
        {
            _instance = this;
            DontDestroyOnLoad(gameObject);
        }
        else if (_instance != this)
        {
            Destroy(gameObject);
        }
    }

    public static UnityMainThreadDispatcher Instance()
    {
        return _instance;
    }

    public void Enqueue(System.Action action)
    {
        if (_instance != null)
        {
            lock (_executionQueue)
            {
                _executionQueue.Enqueue(action);
            }
        }
    }

    void Update()
    {
        lock (_executionQueue)
        {
            while (_executionQueue.Count > 0)
            {
                _executionQueue.Dequeue().Invoke();
            }
        }
    }
}