using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading;
using Melanchall.DryWetMidi.Core;
using Melanchall.DryWetMidi.Devices;
using Melanchall.DryWetMidi.Interaction;
using Melanchall.DryWetMidi.MusicTheory;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Serialization;
using UnityEngine.UI;
using Debug = UnityEngine.Debug;
using Note = Melanchall.DryWetMidi.Interaction.Note;

public sealed class ThreadTickGenerator : TickGenerator
{
    private Thread _thread;
    private bool _isRunning;
    private bool _disposed;

    protected override void Start(TimeSpan interval)
    {
        if (_thread != null)
            return;

        _thread = new Thread(() =>
        {
            var stopwatch = new Stopwatch();
            var lastMs = 0L;

            stopwatch.Start();
            _isRunning = true;

            while (_isRunning)
            {
                var elapsedMs = stopwatch.ElapsedMilliseconds;
                if (elapsedMs - lastMs >= interval.TotalMilliseconds)
                {
                    GenerateTick();
                    lastMs = elapsedMs;
                }
            }
        });

        _thread.Start();
    }

    protected override void Stop()
    {
        _isRunning = false;
        _thread.Abort();
    }

    protected override void Dispose(bool disposing)
    {
        if (_disposed)
            return;

        if (disposing)
        {
            _isRunning = false;
        }

        _disposed = true;
    }
}
public class PlayerMidi : MonoBehaviour
{
    [SerializeField] private Image image;
    [SerializeField] private string filePath = "";
    private List<Note> notes;
    private int position = 0;
    private MidiFile file;
    private Playback playback;
    private static OutputDevice outputDevice;
    private Texture2D texNotes;
    private int nbNote = 0;
    private int sizetex;
    private Camera cam;
    [SerializeField] private Material mat;
    private int currentNote = 0;
    private List<Vector3> notesShader = new List<Vector3>();
    private List<Vector3> notesDataShader = new List<Vector3>();
    private ComputeBuffer buffer;
    private ComputeBuffer bufferData;
    private RenderTexture _bufferResult;
    private RawImage _imageRaw;
    [SerializeField] private Material pixelatedEffect;

    private void OnApplicationQuit()
    {
        Debug.Log("Off");
        playback?.Dispose();
        playback = null;
        outputDevice?.Dispose();
    }

    private void OnDisable()
    {
        if (buffer != null)
        {
            buffer.Dispose();
        }

        if (bufferData != null)
        {
            bufferData.Dispose();
        }

        if (outputDevice != null)
        {
            outputDevice.EventSent -= OnEventSentFunction;
        }

        if (playback != null)
        {
            if (playback.IsRunning)
                playback.Stop();
        }
    }

    private void OnEventSentFunction(object sender, MidiEventSentEventArgs e)
    {
        var midiDevice = (MidiDevice)sender;
        if (e.Event.EventType == MidiEventType.NoteOn)
        {
            nbNote++;
            //var tmp = (NoteOnEvent) (e.Event);
            
            // var tmpValue = new valueNote();
            // tmpValue.value = tmp.NoteNumber / 5f - 10f;
            // tmpValue.velocity = tmp.Velocity;
            // tmpValue.octave = tmp.GetNoteOctave() * 2f - 6f;
            // tmpValue.color = tmp.Channel;
            // create.Add(tmpValue);
        }
        else if (e.Event.EventType == MidiEventType.NoteOff)
        {
            nbNote--;
            nbNote = Mathf.Clamp(nbNote, 0, 10);
            currentNote++;

            // Debug.Log(((InstrumentNameEvent)e.Event).Text);
        }
        // else
        //     Debug.Log($"Event sent to '{midiDevice.Name}' at {DateTime.Now}: {e.Event}");
    } 
    // Start is called before the first frame update
    void OnEnable()
    {
        if (cam == null)
            cam = Camera.main;
       
        file = MidiFile.Read(Application.streamingAssetsPath + "/" + filePath + ".mid");
        notes = (List<Note>)file.GetNotes();
        float maxNoteDuration = Single.NegativeInfinity;
        float minNoteDuration = Single.PositiveInfinity;
        float maxVelocity = Single.NegativeInfinity;
        float maxNoteNumber = Single.NegativeInfinity;
        float maxChannel = 0;
        float maxOctave = 0;
        foreach (Note note in notes)
        {
            if (note.Channel > maxChannel)
                maxChannel = note.Channel;
            if (note.NoteNumber > maxNoteNumber)
                maxNoteNumber = note.NoteNumber;
            if (note.Velocity > maxVelocity)
                maxVelocity = note.Velocity;
            if (note.Length > maxNoteDuration)
                maxNoteDuration = note.Length;
            if (note.Length < minNoteDuration)
                minNoteDuration = note.Length;
            if (note.Octave > maxOctave)
                maxOctave = note.Octave;
        }
        float maxTime = float.Parse(file.GetDuration(TimeSpanType.Midi).ToString());
        sizetex = Mathf.FloorToInt(Mathf.Sqrt(notes[notes.Count - 1].Time + notes[notes.Count - 1].Length));
        texNotes = new Texture2D(sizetex, sizetex, TextureFormat.ARGB32, false);
        texNotes.wrapMode = TextureWrapMode.Repeat;
        _bufferResult = new RenderTexture(texNotes.width, texNotes.height, 50, RenderTextureFormat.ARGB32, 0);
        _bufferResult.format = RenderTextureFormat.ARGBFloat;
        _bufferResult.wrapMode = TextureWrapMode.Repeat;
        _bufferResult.enableRandomWrite = true;
        _bufferResult.depth = 0;
        _bufferResult.volumeDepth = 50;
        _bufferResult.dimension = TextureDimension.Tex3D;
        _bufferResult.Create();
        for (int i = 0; i < notes.Count; i++)
        {
            Color[] colors = new Color[notes[i].Length];
            notesShader.Add(new Vector3(notes[i].Time, notes[i].Length, notes[i].OffVelocity));
            notesDataShader.Add(new Vector3(notes[i].NoteNumber/maxNoteNumber, notes[i].Octave/maxOctave, notes[i].Velocity/maxVelocity));
            for (int j = 0; j < notes[i].Length; j++)
            {
                Color colTmp = texNotes.GetPixel(Mathf.CeilToInt(notes[i].Time + j) % sizetex,
                    Mathf.CeilToInt(notes[i].Time + j) / sizetex);
                colTmp = Color.Lerp(colTmp,
                        new Color((float) notes[i].NoteNumber / maxNoteNumber, (float) notes[i].Velocity / maxVelocity,
                            (float) notes[i].Channel / maxChannel, notes[i].Octave / maxOctave), 1f);
                texNotes.SetPixel(Mathf.CeilToInt(notes[i].Time + j) % sizetex, Mathf.CeilToInt(notes[i].Time + j) / sizetex, colTmp);
            }

        }
        texNotes.Apply();
        buffer = new ComputeBuffer(notesShader.Count, sizeof(float) * 3);
        bufferData = new ComputeBuffer(notesDataShader.Count, sizeof(float) * 3);
        buffer.SetData(notesShader.ToArray());
        bufferData.SetData(notesDataShader.ToArray());
        mat.SetBuffer("_Notes", buffer);
        mat.SetBuffer("_NotesData", bufferData);
        pixelatedEffect.SetBuffer("_NotesData", bufferData);
        mat.SetTexture("_MainTex", texNotes);
        mat.SetInt("_SizeTex", sizetex);
        Sprite tmpSprite = Sprite.Create(texNotes, new Rect(Vector2.zero, new Vector2(sizetex, sizetex)), Vector2.zero);
        mat.SetInt("_nbNote", nbNote);
        image.sprite = tmpSprite;
        outputDevice = OutputDevice.GetById(0);
        outputDevice.EventSent += OnEventSentFunction;
        _imageRaw = FindObjectOfType<RawImage>();
        mat.SetTexture("_ResultBuffer", _bufferResult);
        Graphics.SetRandomWriteTarget(1, _bufferResult);
        playback = file.GetPlayback(outputDevice,
            new MidiClockSettings
            {
                CreateTickGeneratorCallback = () => new ThreadTickGenerator()
            });
        playback.Loop = true;
        playback.Start();
        // playback.TrackNotes = true;
        
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        Graphics.Blit(src, dest, pixelatedEffect);
    }

    private void Update()
    {
        int index = int.Parse(playback.GetCurrentTime(TimeSpanType.Midi).ToString());
        if (Input.GetKey(KeyCode.DownArrow) && index + sizetex < sizetex * sizetex - 1)
        {
            index += sizetex;
            nbNote = 0;
            playback.MoveForward(new MidiTimeSpan(sizetex));
        }

        if (Input.GetKey(KeyCode.UpArrow) && index - sizetex >= 0)
        {
            index -= sizetex;
            nbNote = 0;
            playback.MoveBack(new MidiTimeSpan(sizetex));
        }

        if (Input.GetKey(KeyCode.RightArrow) && index + 1 < sizetex * sizetex - 1)
        {
            index++;
            nbNote = 0;
            playback.MoveForward(new MidiTimeSpan(1));
        }

        if (Input.GetKey(KeyCode.LeftArrow) && index - 1 >= 0)
        {
            index--;
            nbNote = 0;
            playback.MoveBack(new MidiTimeSpan(1));
        }
        mat.SetInt("_Index", index);
        mat.SetInt("_nbNote", nbNote);
        if (notesShader.Exists(vector => vector.x + vector.y == index))
            currentNote = notesShader.IndexOf(notesShader.Find(vector => vector.x + vector.y == index));
        mat.SetInt("_currentNote", currentNote);
        pixelatedEffect.SetInt("_currentNote", currentNote);
    }
}