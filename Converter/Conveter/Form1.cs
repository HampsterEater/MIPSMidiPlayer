using System;
using System.IO;
using System.Diagnostics;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;

namespace Conveter
{
    /// <summary>
    ///     This form is used to display to the user the front end for our midi to asmdat converter.
    /// </summary>
    public partial class Form1 : Form
    {
        /// <summary>
        ///     Constructs this class.
        /// </summary>
        public Form1()
        {
            InitializeComponent();
        }

        /// <summary>
        ///     Invoked if the select input button is clicked.
        /// </summary>
        /// <param name="sender">Object that invoked this event.</param>
        /// <param name="e">Event arguments.</param>
        private void button1_Click(object sender, EventArgs e)
        {
            OpenFileDialog dialog = new OpenFileDialog();
            dialog.Title = "Select MIDI File...";
            dialog.Filter = "MIDI Files|*.mid;*.midi";
            if (dialog.ShowDialog() == DialogResult.OK)
            {
                textBox1.Text = dialog.FileName;
               // if (textBox2.Text == "")
                    textBox2.Text = dialog.FileName + ".asmdat";
            }

            button3.Enabled = (File.Exists(textBox1.Text) && textBox2.Text != "");
        }

        /// <summary>
        ///     Invoked if the select output button is clicked.
        /// </summary>
        /// <param name="sender">Object that invoked this event.</param>
        /// <param name="e">Event arguments.</param>
        private void button2_Click(object sender, EventArgs e)
        {
            SaveFileDialog dialog = new SaveFileDialog();
            dialog.Title = "Select Output File...";
            dialog.Filter = "ASM Data Files|*.asmdat";
            if (dialog.ShowDialog() == DialogResult.OK)
            {
                textBox2.Text = dialog.FileName;
            }

            button3.Enabled = (File.Exists(textBox1.Text) && textBox2.Text != "");
        }

        /// <summary>
        ///     Invoked if the convert button is clicked.
        /// </summary>
        /// <param name="sender">Object that invoked this event.</param>
        /// <param name="e">Event arguments.</param>
        private void button3_Click(object sender, EventArgs e)
        {
            bool failed = false;

            button3.Enabled = false;
            button3.Text = "Converting ...";

#if !DEBUG
            try
            {
#endif
                if (ConvertFile(textBox1.Text, textBox1.Text + ".tmp", textBox2.Text) == false)
                    failed = true;            
#if !DEBUG
            }
            catch (Exception)
            {
                failed = true;
            }   
#endif
                if (failed == true)
                MessageBox.Show("An error occured while trying to convert file. Are you sure file is in correct format?", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            else
                MessageBox.Show("Conversion was successfull.", "Success", MessageBoxButtons.OK, MessageBoxIcon.Information);

            button3.Enabled = true;
            button3.Text = "Convert File";

            return;
        }

        /// <summary>
        ///     Takes an input midi file and converts it to a asmdat file by putting it through MIDIFile2Text.jar, parsing
        ///     the output and encoding it in binary.
        /// </summary>
        /// <param name="inputFile">Input filename of midi.</param>
        /// <param name="temporaryDirectory">Directory to hold temporary files in.</param>
        /// <param name="outputFile">Output filename of asmdat</param>
        /// <returns>True on success, otherwise false.</returns>
        private bool ConvertFile(string inputFile, string temporaryDirectory, string outputFile)
        {
            string temporaryFileName = temporaryDirectory + "\\" + Path.GetFileNameWithoutExtension(inputFile) + ".dat";
            int ppq = 240;

            // Delete old temporary files.
            if (File.Exists(temporaryFileName))
                File.Delete(temporaryFileName);
            if (File.Exists(outputFile))
                File.Delete(outputFile);

            // First tell MIDI2TEXT to convert our input file 
            // into a text file.
            ProcessStartInfo info = new ProcessStartInfo(@"java.exe");
            info.Arguments = "-jar \"" + Environment.CurrentDirectory + "\\MIDIFile2Text.jar\" -on-off-accumulate-progchange-controlchange-chanpres-pitchwheel-header-tempo \"" + inputFile + "\" \"" + temporaryDirectory + "\"";
            info.UseShellExecute = false;
            info.RedirectStandardOutput = true;

            Process process = Process.Start(info);
            if (process == null)
                return false;

            // Print out all the output of the converter.
            while (process.HasExited == false)
            {
                string line = process.StandardOutput.ReadLine();
                System.Console.WriteLine(line + "\n");
            }

            // Load in all text in the temporary conversion file.
            string[] lines = File.ReadAllLines(temporaryFileName);

            // Go through and create note objects for each line in the file.
            List<Note> noteList = new List<Note>();
            for (int i = 0; i < lines.Length; i++)
            {
                string line = lines[i];
                string[] segments = line.Split('\t');

                // Read in ppq.
                if (line.Substring(0, 5) == "PPQ: ")
                {
                    int endIndex = line.IndexOf(' ', 5);
                    string time = line.Substring(5, endIndex - 5);
                    ppq = int.Parse(time);
                }

                // Skip data headers.
                if (segments[0] == "cumTime")
                    continue;

                if (segments.Length == 7)
                {
                    try
                    {
                        bool noAdd = false;

                        // Create our note depending on what kind of event it is.
                        Note note = new Note();
                        note.cumTime = segments[0] == "" ? 0 : int.Parse(segments[0]);
                        note.delTime = segments[1] == "" ? 0 : int.Parse(segments[1]);
                        switch (segments[2])
                        {
                            case "non":
                                note.eventType = NoteEventType.NoteOn;
                                break;
                            case "pch":
                                note.eventType = NoteEventType.ProgramChange;
                                break;
                            default:
                                noAdd = true;
                                break;
                        }
                        note.pitch = segments[3] == "" ? 0 : int.Parse(segments[3]);
                        note.vel = segments[4] == "" ? 0 : int.Parse(segments[4]);
                        note.chan = segments[5] == "" ? 0 : int.Parse(segments[5]);
                        note.value = segments[6] == "" ? 0 : int.Parse(segments[6]);

                        if (noAdd == false)
                            noteList.Add(note);
                    }
                    catch (Exception)
                    {
                    }
                }
            }

            // Sort list by time.
            noteList.Sort(
                delegate(Note n1, Note n2)
                {
                    return n1.cumTime.CompareTo(n2.cumTime);
                }
            );

            // Write out all the notes into a memory stream ready for RLE.
            Stream stream = new MemoryStream();
            BinaryWriter writer = new BinaryWriter(stream);

            // Write out notes
            foreach (Note note in noteList)
            {
                writer.Write((int)note.cumTime);
                writer.Write((int)note.delTime);
                writer.Write((byte)note.eventType);
                writer.Write((byte)note.pitch);
                writer.Write((byte)note.vel);
                writer.Write((byte)note.value);
                writer.Write((int)note.chan);
            }

            stream.Flush();
            byte[] uncompressedData = ((MemoryStream)stream).ToArray();

            writer.Close();
            stream.Close();

            // Compress stream.
            byte[] compressedData = RLECompress(uncompressedData);

            // Write out all data into file.
            stream = new FileStream(outputFile, FileMode.Create, FileAccess.Write);
            writer = new BinaryWriter(stream);
            
            // Header
            writer.Write(noteList.Count);
            writer.Write(ppq);
            writer.Write(compressedData.Length);

            // Compressed Notes
            writer.Write(compressedData, 0, compressedData.Length);

            writer.Close();
            stream.Close();

            // Clean up temporary files.
#if !DEBUG
            if (File.Exists(temporaryFileName))
                File.Delete(temporaryFileName);
            if (Directory.Exists(temporaryDirectory))
                Directory.Delete(temporaryDirectory);
#endif

            return true;
        }

        /// <summary>
        ///     Compresses an array of bytes using my own crude form of RLE.
        /// </summary>
        /// <param name="data">Data to compress.</param>
        /// <returns>Compressed version of data buffer.</returns>
        public byte[] RLECompress(byte[] data)
        {
            MemoryStream compressedStream = new MemoryStream();
            BinaryWriter compressedWriter = new BinaryWriter(compressedStream);

            // Go through and compress.
            for (int i = 0; i < data.Length; i++)
            {
                // Count how many repetitions there are of the current byte.
                byte currentByte = data[i];
                int repetitions = 0;
                for (int k = i + 1; k < data.Length; k++)
                {
                    if (data[k] == currentByte)
                        repetitions++;
                    else
                        break;
                }

                // If there are more than 2 (if there is less, we just end up making the file bigger) and less than 127 (we can't support more
                // than this using the control character method we are using).
                if (repetitions >= 2 && repetitions < 127)
                {
                    byte controlByte = (byte)(127 + 1 + repetitions);
                    compressedWriter.Write(controlByte);
                    compressedWriter.Write(data[i]);

                    i += repetitions;
                }

                // If not just encode the current byte without compression.
                else
                {
                    if (data[i] > 127)
                    {
                        byte controlByte = (byte)(127 + 1);
                        compressedWriter.Write(controlByte);
                        compressedWriter.Write(data[i]);
                    }
                    else
                        compressedWriter.Write(data[i]);
                }
            }

            // Flush the stream and covert to an array ready to return.
            compressedStream.Flush();
            byte[] compressedData = compressedStream.ToArray();

            compressedWriter.Close();
            compressedStream.Close();

            return compressedData;
        }

    }

    /// <summary>
    ///     Used to identify the different type of midi events that we can process.
    /// </summary>
    public enum NoteEventType
    {
        NoteOn = 0,
        ProgramChange = 1,
        ControlChange = 2,
    }

    /// <summary>
    ///     Most important class in this app, stores all the information needed
    ///     to play a specific note.
    /// </summary>
    public class Note
    {
        public int cumTime;
        public int delTime;
        public NoteEventType eventType;
        public int pitch;
        public int vel;
        public int chan;
        public int value;
    }
}
