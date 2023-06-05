// Buffer Arpeggiator
// v6.2
// Last updated by Spyro Pallis
// 6.4.23

// Server settings

// For bluetooth headphones
s.options.hardwareBufferSize = 256;

// For recording .wav files
s.recHeaderFormat = "wav";

// Server memory boost
s.options.memSize = 65536*4;

// Boot server
s.boot;

// Function calling for quick boot
// Functions must be initialized before calling
(
~tempo.value();
~patches.value();
~synthdefs.value();
~buffers.value();

~gui.value();
~midi.value();
~switches.value();
~patterns.value();
)

// Tempo function
(
(
~tempo = {(

	// Queue size increases performance for higher tempos
	t = TempoClock.new(137/60, queueSize: 2048 * 128);
	t.tempo_(137/60);
)};
);
~tempo.value();
)

// Patches function
(
(
~patches = {(

	// Establishing order of execution for Synths
	// Head and tail
	~sources = Group.head;
	~mixer = Group.tail;

	// Patches (audio buses) 1-4
	~patch1 = Bus.audio(s, 2);
	~patch2 = Bus.audio(s, 2);
	~patch3 = Bus.audio(s, 2);
	~patch4 = Bus.audio(s, 2);

	// Channels 1-3, master, and record
	~channel1 = Group.tail(~mixer);
	~channel2 = Group.tail(~mixer);
	~channel3 = Group.tail(~mixer);
	~master = Group.tail(~mixer);
	~record = Group.tail(~mixer);
)};
);
~patches.value();
)

//SynthDefs function
(
(
~synthdefs = {(

	// Scales
	~s = Scale.minor.degrees.midiratio;
	~d = Scale.major.degrees.midiratio;

	// Main PlayBuf SynthDef for samples
	SynthDef.new(\mainbuf, {
		arg amp = 1, pan = 0, rate = 1, pos = 0, bank, atk = 0.01, rel = 1, loop = 1, gate = 1, fader = 1, patch = 22, bufrate = 44100, smoothing = 0.5;
		var sig, env, z;
		env = EnvGen.kr(Env.perc(atk, rel), gate, doneAction: 2);
		sig = PlayBuf.ar(1, bank, BufRateScale.kr(bank) * rate, 1, pos, loop) * env;
		sig = Pan2.ar(sig, pan);
		sig = Out.ar(patch, sig * amp);
	}).add;

	// All audio signals are routed through Channels 1 - 3 based on patch. Master output is 'master channel
	// Channel 1
	~channel1 = (
		SynthDef(\ch1mix, {
			arg moogcut = 21000, gain = 0, highcut = 22, lowcut = 22, fader = 1, crossfader = 1, maxdelaytime = 0.2, delaytime = 0.2, decaytime = 1.0, mul = 1, pitchRatio = 1, pitchDispersion = 0, timeDispersion = 0;
			var sig;
			sig = In.ar(~patch1, 2);
			sig = MoogFF.ar(sig, moogcut, gain);
			sig = AllpassC.ar(sig, maxdelaytime, delaytime, decaytime, mul);
			sig = HPF.ar(sig, highcut);
			sig = PitchShift.ar(sig, delaytime, pitchRatio, pitchDispersion, timeDispersion);
			sig = Out.ar(~patch4, sig);
		}).play(~channel1);
	);

	// Channel 2
	~channel2 = (
		SynthDef(\ch2mix, {
			arg moogcut = 21000, gain = 0, highcut = 22, lowcut = 22, fader = 1, crossfader = 1, maxdelaytime = 0.2, delaytime = 0.2, decaytime = 1.0, mul = 1, pitchRatio = 1, pitchDispersion = 0, timeDispersion = 0;
			var sig;
			sig = In.ar(~patch2, 2);
			sig = MoogFF.ar(sig, moogcut, gain);
			sig = AllpassC.ar(sig, maxdelaytime, delaytime, decaytime, mul);
			sig = HPF.ar(sig,highcut);
			sig = PitchShift.ar(sig, delaytime, pitchRatio, pitchDispersion, timeDispersion);
			sig = Out.ar(~patch4, sig);
		}).play(~channel2);
	);

	// Channel 3
	~channel3 = (
		SynthDef(\ch3mix, {
			arg moogcut = 21000, gain = 0, highcut = 22, lowcut = 22, fader = 1, crossfader = 1, maxdelaytime = 0.2, delaytime = 0.2, decaytime = 1.0, mul = 1, pitchRatio = 1, pitchDispersion = 0, timeDispersion = 0;
			var sig;
			sig = In.ar(~patch3, 2);
			sig = MoogFF.ar(sig, moogcut, gain);
			sig = AllpassC.ar(sig, maxdelaytime, delaytime, decaytime, mul);
			sig = HPF.ar(sig, highcut);
			sig = PitchShift.ar(sig, delaytime, pitchRatio, pitchDispersion, timeDispersion);
			sig = Out.ar(~patch4, sig);
		}).play(~channel3);
	);

	// Master channel
	~master = (
		SynthDef(\mastermix, {
			arg moogcut = 29000, gain = 0, highcut = 22, mix = 0.33, room = 0.5, damp = 0.5;
			var sig;
			sig = In.ar(~patch4, 2);
			//sig = FreeVerb.ar(sig, mix, room, damp);
			//sig = Compander.ar(sig);
			//sig = Limiter.ar(sig);
			sig = Out.ar(0, sig);
		}).play(~master);
	);
)};
);
~synthdefs.value();
)

// Buffers function
(
(
~buffers = {(

	// Free all buffers when this is called.
	Buffer.freeAll;

	// Array for holding buffers
	~bufbank = Array.newClear(80);

	// Read 80 samples from local directory and load them to array
	80.do({ arg i;
		~bufbank[i] = Buffer.readChannel(s, "/Users/spyridonpallis/Documents/SuperCollider/Samples/D7X/untitled" ++ (i+1).asString ++ ".wav", channels: [0]);
	});

	// Add 8 empty buffers to the end of the array (Used for RecordBuf)
	8.do({ arg i;
		~bufbank.add(Buffer.alloc(s, s.sampleRate * 4.0, 1));
	});
);
};
);
~buffers.value();
)

// GUI
(
(
~gui = {(
	{
		// Resets window each time this is called
		Window.closeAll;
		w = Window("Buffer Arpeggiator", Rect(800, 300, 300, 200));
		w.view.background_(Color.clear);
		w.front;
		w.alwaysOnTop_(true);
	}.value();

	// Initiating default global variables for steps
	~steps1 = 0;
	~steps2 = 0;
	~steps3 = 0;

	// Initiating default global variables for input entry
	~ch1_pseq_entry = "1";
	~ch2_pseq_entry = "1";
	~ch3_pseq_entry = "1";

	// Text for Sources and Channel
	~sourceText1 = StaticText(w, Rect(10, 0, 100, 20));
	~sourceText2 = StaticText(w, Rect(60, 0, 100, 20));
	~sourceText3 = StaticText(w, Rect(100, 0, 100, 20));
	~channelText1 = StaticText(w, Rect(160, 0, 100, 20));
	~sourceText1.string = "Source:";
	~sourceText2.string = "SC";
	~sourceText3.string = "MIDI";
	~channelText1.string = "Channel:";
	~sourceCheckbox1 = CheckBox(w, Rect(80, 1, 20, 20));

	// Source checkbox1 actions
	~sourceCheckbox1.action_({
		MIDIdef.freeAll;
		~midiSwitch = false;
		~sourceCheckbox1.value = true;
		if (~sourceCheckbox1.value == true && ~channelButton1.value == 1, {
			~midiConnectedText.visible = false;
			~sourceCheckbox2.value = false;
			~ch1_inputText.visible = true;
			~ch1_inputTextField.visible = true;});
		if (~sourceCheckbox1.value == true && ~channelButton2.value == 1, {
			~midiConnectedText.visible = false;
			~sourceCheckbox2.value = false;
			~ch2_inputText.visible = true;
			~ch2_inputTextField.visible = true;});
		if (~sourceCheckbox1.value == true && ~channelButton3.value == 1, {
			~midiConnectedText.visible = false;
			~sourceCheckbox2.value = false;
			~ch3_inputText.visible = true;
			~ch3_inputTextField.visible = true;
		});
	});
	~sourceCheckbox1.doAction;

	// Source checkbox2 actions
	~sourceCheckbox2 = CheckBox(w, Rect(130, 1, 20, 20));
	~sourceCheckbox2.action_({
		if (~sourceCheckbox2.value == true && ~channelButton1.value == 1, {
			~midiSwitch = true;
			~ch1_midiInput = true;
			~midi.value();
			~midiConnectedText.visible = true;
			~sourceCheckbox1.value = false;
			~ch1_inputText.visible = false;
			~ch1_inputTextField.visible = false;
			~ch2_inputText.visible = false;
			~ch2_inputTextField.visible = false;
			~ch3_inputText.visible = false;
			~ch3_inputTextField.visible = false;
		});
		if (~sourceCheckbox2.value == true && ~channelButton2.value == 1, {
			~midiSwitch = true;
			~ch2_midiInput = true;
			~midi.value();
			~midiConnectedText.visible = true;
			~sourceCheckbox1.value = false;
			~ch1_inputText.visible = false;
			~ch1_inputTextField.visible = false;
			~ch2_inputText.visible = false;
			~ch2_inputTextField.visible = false;
			~ch3_inputText.visible = false;
			~ch3_inputTextField.visible = false;
		});
		if (~sourceCheckbox2.value == true && ~channelButton2.value == 1, {
			~midiSwitch = true;
			~ch3_midiInput = true;
			~midi.value();
			~midiConnectedText.visible = true;
			~sourceCheckbox1.value = false;
			~ch1_inputText.visible = false;
			~ch1_inputTextField.visible = false;
			~ch2_inputText.visible = false;
			~ch2_inputTextField.visible = false;
			~ch3_inputText.visible = false;
			~ch3_inputTextField.visible = false;
		});
	});
	~sourceCheckbox2.doAction;

	// Channels 1-3 buttons
	// Each channel is unique instance of input, style, transpose, steps
	~channelButton1 = Button(w, Rect(220, 0, 20, 20));
	~channelButton2 = Button(w, Rect(245, 0, 20, 20));
	~channelButton3 = Button(w, Rect(270, 0, 20, 20));

	~channelButton1.states_([
		["1", Color.black, Color.white(1.2438, 0.9632)],
		["1", Color.white, Color.black(0.538, 0.99)],
	]);
	~ch1_inputText = StaticText(w, Rect(10, 20, 100, 20));
	~ch1_inputTextField = TextField(w, Rect(50, 20, 100, 20));
	~ch1_styleText = StaticText(w, Rect(10, 40, 100, 20));
	~ch1_styleMenu = PopUpMenu(w, Rect(10, 60, 80, 20)).items_(["Up", "UpDown", "Down", "DownUp"]);
	~ch1_transposeText = StaticText(w, Rect(200, 40, 100, 20));
	~ch1_transposeMenu = PopUpMenu(w, Rect(200, 60, 90, 20)).items_(["Shift", "Major", "Minor"]);
	~ch1_stepsText = StaticText(w, Rect(200, 80, 90, 20));
	~ch1_stepsSpec = [-10, 10,'linear',1].asSpec;
	~ch1_stepsKnob = Knob.new(w, Rect(200, 100, 30, 30));
	~ch1_stepsValue = StaticText(w, Rect(240, 100, 80, 20)).string_("Val: ");

	// Action for dislaying step value
	~ch1_stepsKnob.action_({
		|v,x,y,m|
		~steps1 = ~ch1_stepsSpec.map(v.value).value;
		if (~steps1.value == 0, {
			~ch1_stepsValue.string_("Val: 0.0");
		});
		if (~steps1.value != 0, {
			~ch1_stepsValue.string_("Val: " ++ ~ch1_stepsSpec.map(v.value));
		});
		~switches.value();
		~patterns.value();
	}).value_(~ch1_stepsSpec.unmap(0));
	~ch1_stepsKnob.doAction;
	~ch1_inputText.string = "Input:";
	~ch1_inputTextField.string = "ex. 45, 52, 75";
	~ch1_styleText.string = "Style:";
	~ch1_transposeText.string = "Transpose:";
	~ch1_stepsText.string = "Steps:";

	~channelButton2.states_([
		["2", Color.black, Color.white(1.2438, 0.9632)],
		["2", Color.white, Color.black(0.538, 0.99)],
	]);
	~ch2_inputText = StaticText(w, Rect(10, 20, 100, 20));
	~ch2_inputTextField = TextField(w, Rect(50, 20, 100, 20));
	~ch2_styleText = StaticText(w, Rect(10, 40, 100, 20));
	~ch2_styleMenu = PopUpMenu(w, Rect(10, 60, 80, 20)).items_(["Up", "UpDown", "Down", "DownUp"]);
	~ch2_transposeText = StaticText(w, Rect(200, 40, 100, 20));
	~ch2_transposeMenu = PopUpMenu(w, Rect(200, 60, 90, 20)).items_(["Shift", "Major", "Minor"]);
	~ch2_stepsText = StaticText(w, Rect(200, 80, 90, 20));
	~ch2_stepsSpec = [-10, 10,'linear',1].asSpec;
	~ch2_stepsKnob = Knob.new(w, Rect(200, 100, 30, 30));
	~ch2_stepsValue = StaticText(w, Rect(240, 100, 80, 20)).string_("Val: ");
	~ch2_stepsKnob.action_({
		|v,x,y,m|
		~steps2 = ~ch2_stepsSpec.map(v.value).value;
		if (~steps2.value == 0, {
			~ch2_stepsValue.string_("Val: 0.0");
		});
		if (~steps2.value != 0, {
			~ch2_stepsValue.string_("Val: " ++ ~ch2_stepsSpec.map(v.value));
		});
		~switches.value();
		~patterns.value();
	}).value_(~ch2_stepsSpec.unmap(0));
	~ch2_stepsKnob.doAction;
	~ch2_inputText.string = "Input:";
	~ch2_inputTextField.string = "ex. 45, 52, 75";
	~ch2_styleText.string = "Style:";
	~ch2_transposeText.string = "Transpose:";
	~ch2_stepsText.string = "Steps:";

	~channelButton3.states_([
		["3", Color.black, Color.white(1.2438, 0.9632)],
		["3", Color.white, Color.black(0.538, 0.99)],
	]);
	~ch3_inputText = StaticText(w, Rect(10, 20, 100, 20));
	~ch3_inputTextField = TextField(w, Rect(50, 20, 100, 20));
	~ch3_styleText = StaticText(w, Rect(10, 40, 100, 20));
	~ch3_styleMenu = PopUpMenu(w, Rect(10, 60, 80, 20)).items_(["Up", "UpDown", "Down", "DownUp"]);
	~ch3_transposeText = StaticText(w, Rect(200, 40, 100, 20));
	~ch3_transposeMenu = PopUpMenu(w, Rect(200, 60, 90, 20)).items_(["Shift", "Major", "Minor"]);
	~ch3_stepsText = StaticText(w, Rect(200, 80, 90, 20));
	~ch3_stepsSpec = [-10, 10,'linear',1].asSpec;
	~ch3_stepsKnob = Knob.new(w, Rect(200, 100, 30, 30));
	~ch3_stepsValue = StaticText(w, Rect(240, 100, 80, 20)).string_("Val: ");
	~ch3_stepsKnob.action_({
		|v,x,y,m|
		~steps3 = ~ch3_stepsSpec.map(v.value).value;
		if (~steps3.value == 0, {
			~ch3_stepsValue.string_("Val: 0.0");
		});
		if (~steps3.value != 0, {
			~ch3_stepsValue.string_("Val: " ++ ~ch3_stepsSpec.map(v.value));
		});
		~switches.value();
		~patterns.value();
	}).value_(~ch3_stepsSpec.unmap(0));
	~ch3_stepsKnob.doAction;
	~ch3_inputText.string = "Input:";
	~ch3_inputTextField.string = "ex. 45, 52, 75";
	~ch3_styleText.string = "Style:";
	~ch3_transposeText.string = "Transpose:";
	~ch3_stepsText.string = "Steps:";

	// Channel 1 - 3 button actions
	// Mainly for toggling visibility for each channel's instance
	// I.e if channel 1 is selected, input, style, transpose, steps for 2 and 3 are not visible
	~channelButton1.action_({
		if (~sourceCheckbox1.value == true || ~sourceCheckbox2.value == true, {
			~channelButton1.value = 1;
			~ch1_inputText.visible = true;
			~ch1_inputTextField.visible = true;
			~ch1_styleText.visible = true;
			~ch1_styleMenu.visible = true;
			~ch1_transposeText.visible = true;
			~ch1_transposeMenu.visible = true;
			~ch1_stepsText.visible = true;
			~ch1_stepsKnob.visible = true;
			~ch1_stepsValue.visible = true;
			~ch2_inputText.visible = false;
			~ch2_inputTextField.visible = false;
			~ch2_styleText.visible = false;
			~ch2_styleMenu.visible = false;
			~ch2_transposeText.visible = false;
			~ch2_transposeMenu.visible = false;
			~ch2_stepsText.visible = false;
			~ch2_stepsKnob.visible = false;
			~ch2_stepsValue.visible = false;
			~ch3_inputText.visible = false;
			~ch3_inputTextField.visible = false;
			~ch3_styleText.visible = false;
			~ch3_styleMenu.visible = false;
			~ch3_transposeText.visible = false;
			~ch3_transposeMenu.visible = false;
			~ch3_stepsText.visible = false;
			~ch3_stepsKnob.visible = false;
			~ch3_stepsValue.visible = false;
		});
		if (~channelButton1.value == 1, {~channelButton2.value = 0});
		if (~channelButton1.value == 1, {~channelButton3.value = 0});
	});
	~channelButton1.doAction;
	~ch1_styleMenu.action_({
		if (~ch1_styleMenu.value == 0, {~switches.value()});
		if (~ch1_styleMenu.value == 1, {~switches.value()});
		if (~ch1_styleMenu.value == 2, {~switches.value()});
		if (~ch1_styleMenu.value == 3, {~switches.value()});
	});
	~channelButton2.action_({
		if (~sourceCheckbox1.value == true, {
			~ch1_inputText.visible = false;
			~ch1_inputTextField.visible = false;
			~ch1_styleText.visible = false;
			~ch1_styleMenu.visible = false;
			~ch1_transposeText.visible = false;
			~ch1_transposeMenu.visible = false;
			~ch1_stepsText.visible = false;
			~ch1_stepsKnob.visible = false;
			~ch1_stepsValue.visible = false;
			~ch2_inputText.visible = true;
			~ch2_inputTextField.visible = true;
			~ch2_styleText.visible = true;
			~ch2_styleMenu.visible = true;
			~ch2_transposeText.visible = true;
			~ch2_transposeMenu.visible = true;
			~ch2_stepsText.visible = true;
			~ch2_stepsKnob.visible = true;
			~ch2_stepsValue.visible = true;
			~ch3_inputText.visible = false;
			~ch3_inputTextField.visible = false;
			~ch3_styleText.visible = false;
			~ch3_styleMenu.visible = false;
			~ch3_transposeText.visible = false;
			~ch3_transposeMenu.visible = false;
			~ch3_stepsText.visible = false;
			~ch3_stepsKnob.visible = false;
			~ch3_stepsValue.visible = false;
		});
		if (~channelButton2.value == 1, {~channelButton1.value = 0});
		if (~channelButton2.value == 1, {~channelButton3.value = 0});
	});
	~ch2_styleMenu.action_({
		if (~ch2_styleMenu.value == 0, {~switches.value()});
		if (~ch2_styleMenu.value == 1, {~switches.value()});
		if (~ch2_styleMenu.value == 2, {~switches.value()});
		if (~ch2_styleMenu.value == 3, {~switches.value()});
	});
	~channelButton3.action_({
		if (~sourceCheckbox1.value == true, {
			~ch1_inputText.visible = false;
			~ch1_inputTextField.visible = false;
			~ch1_styleText.visible = false;
			~ch1_styleMenu.visible = false;
			~ch1_transposeText.visible = false;
			~ch1_transposeMenu.visible = false;
			~ch1_stepsText.visible = false;
			~ch1_stepsKnob.visible = false;
			~ch1_stepsValue.visible = false;
			~ch2_inputText.visible = false;
			~ch2_inputTextField.visible = false;
			~ch2_styleText.visible = false;
			~ch2_styleMenu.visible = false;
			~ch2_transposeText.visible = false;
			~ch2_transposeMenu.visible = false;
			~ch2_stepsText.visible = false;
			~ch2_stepsKnob.visible = false;
			~ch2_stepsValue.visible = false;
			~ch3_inputText.visible = true;
			~ch3_inputTextField.visible = true;
			~ch3_styleText.visible = true;
			~ch3_styleMenu.visible = true;
			~ch3_transposeText.visible = true;
			~ch3_transposeMenu.visible = true;
			~ch3_stepsText.visible = true;
			~ch3_stepsKnob.visible = true;
			~ch3_stepsValue.visible = true;
		});
		if (~channelButton3.value == 1, {~channelButton1.value = 0});
		if (~channelButton3.value == 1, {~channelButton2.value = 0});
	});
	~ch3_styleMenu.action_({
		if (~ch3_styleMenu.value == 0, {~switches.value()});
		if (~ch3_styleMenu.value == 1, {~switches.value()});
		if (~ch3_styleMenu.value == 2, {~switches.value()});
		if (~ch3_styleMenu.value == 3, {~switches.value()});
	});

	// Input variable capturing
	// Setting the global var '~ch[x]_pseq_entry = field.value
	// Then calling switches and patterns to update values
	~ch1_inputTextField.action = {
		arg field;
		~ch1_pseq_entry = field.value;
		~switches.value();
		~patterns.value();
	};
	~ch2_inputTextField.action = {
		arg field;
		~ch2_pseq_entry = field.value;
		~switches.value();
		~patterns.value();
	};
	~ch3_inputTextField.action = {
		arg field;
		~ch3_pseq_entry = field.value;
		~switches.value();
		~patterns.value();
	};

	// Midi connection text
	~midiConnectedText = StaticText(w, Rect(10, 20, 200, 20));
	~midiConnectedText.string = "Midi successfully connected!";
	~midiConnectedText.visible = false;

	// Resampler
	// Buffers are predetermined so this records for 4 seconds
	// RecordBuf is added to the tail of the node tree to capture Master out
	// Can be put inside if statement that is triggered if Midi key or button is pressed
	~resamplerText = StaticText(w, Rect(10, 80, 100, 20));
	~resamplerText.string = 'Resample:';
	~resamplerButton = Button(w, Rect(10, 100, 40, 26))
	.states_([["Rec", Color.black, Color.white]])
	.action_({

		// Erase buffer contents
		~bufbank[80].zero;

		// Record master output
		a = {
			var sig;
			'Recording...'.postln;
			sig = In.ar(0, 1);
			RecordBuf.ar(sig, ~bufbank[80], 0, 1, 0, 1, 0, 1, 0);
		}.play(~record);

		// Start a routine to wait for 4 seconds
		Routine({
			4.do({ |count|
				count.postln;
				1.wait;
			});

			// Release the RecordBuf
			a.release(0.1);
			'Finished recording'.postln;
		}).play;
	});
);
};
);
~gui.value();
)

// Midi connection function
(
(
~midi = {(

	// If midi checkbox is selected, then proceed
	// Initialize midi connection
	if(~midiSwitch == true, {
		MIDIdef.freeAll;
		if (~midi_initilized.isNil) {
			MIDIClient.init;
			MIDIIn.connectAll;
			~midi_initialized = 1;
		};

		// Note table (array)
		~note_table = 0!127;
		~n = nil;

		// Once key is pressed down, do the following
		MIDIdef.noteOn(
			\mynoteonhandler,
			{

				// Assign value of key to the note table
				|val, num, chan, src|
				~note_table[num] = 1;
				~n = ~note_table.selectIndices({|item, i| item != 0});
				~n.asString;
				{
					// Update the value based on which channel is selected
					if (~sourceCheckbox2.value == true && ~channelButton1.value == 1, {
						~ch1_pseq_entry = ~n.join(", ");
					};
					);
					if (~sourceCheckbox2.value == true && ~channelButton2.value == 1, {
						~ch2_pseq_entry = ~n.join(", ");
					};
					);
					if (~sourceCheckbox2.value == true && ~channelButton3.value == 1, {
						~ch3_pseq_entry = ~n.join(", ");
					};
					);

					// Call switches / patterns for updating
					~switches.value();
					~patterns.value();
				}.defer;
			}
		);
		MIDIdef.noteOff(
			\mynoteoffhandler,
			{
				|val, num, chan, src|
				~note_table[num] = 0;
			}
		);
	};
	);
);
};
);
~midi.value();
)

// Switches
(
(
~switches = {(

	// Functions for relating the manual and midi input to buffer bank
	// Gets the value then pulls the buffer based on index
	~ch1_bufArray = { |list|
		list.collect {|num|
			~bufbank[num-1+~steps1]
		}
	};
	~ch2_bufArray = { |list|
		list.collect {|num|
			~bufbank[num-1+~steps2]
		}
	};
	~ch3_bufArray = { |list|
		list.collect {|num|
			~bufbank[num-1+~steps3]
		}
	};

	// Style functions for pdef
	// Takes the inputs, puts it into Patterns that can be easily called inside a Pbind
	{
		if (~sourceCheckbox1.value == true || ~sourceCheckbox2.value == true && ~channelButton1.value == 1, {
			if (~ch1_styleMenu.value == 0, {
				~ch1_pseq_buf = Pseq(~ch1_bufArray.(list: ~ch1_pseq_entry.split($,).asFloat), 1);
				~patterns.value();
			});
			if (~ch1_styleMenu.value == 1, {
				~ch1_pseq_buf = Pseq([Pseq(~ch1_bufArray.(list: ~ch1_pseq_entry.split($,).asFloat), 1), Pseq(~ch1_bufArray.(list: ~ch1_pseq_entry.split($,).asFloat).reverse, 1)], inf);
				~patterns.value();
			});
			if (~ch1_styleMenu.value == 2, {
				~ch1_pseq_buf = Pseq(~ch1_bufArray.(list: ~ch1_pseq_entry.split($,).asFloat).reverse, 1);
				~patterns.value();
			});
			if (~ch1_styleMenu.value == 3, {
				~ch1_pseq_buf = Pseq([Pseq(~ch1_bufArray.(list: ~ch1_pseq_entry.split($,).asFloat).reverse, 1), Pseq(~ch1_bufArray.(list: ~ch1_pseq_entry.split($,).asFloat), 1)], 1);
				~patterns.value();
			});
		};
		);
		if (~sourceCheckbox1.value == true || ~sourceCheckbox2.value == true && ~channelButton2.value == 1, {
			if (~ch2_styleMenu.value == 0, {
				~ch2_pseq_buf = Pseq(~ch1_bufArray.(list: ~ch2_pseq_entry.split($,).asFloat), 1);
				~patterns.value();
			});
			if (~ch2_styleMenu.value == 1, {
				~ch2_pseq_buf = Pseq([Pseq(~ch2_bufArray.(list: ~ch2_pseq_entry.split($,).asFloat), 1), Pseq(~ch2_bufArray.(list: ~ch2_pseq_entry.split($,).asFloat).reverse, 1)], 1);
				~patterns.value();
			});
			if (~ch2_styleMenu.value == 2, {
				~ch2_pseq_buf = Pseq(~ch2_bufArray.(list: ~ch2_pseq_entry.split($,).asFloat).reverse, 1);
				~patterns.value();
			});
			if (~ch2_styleMenu.value == 3, {
				~ch2_pseq_buf = Pseq([Pseq(~ch2_bufArray.(list: ~ch2_pseq_entry.split($,).asFloat).reverse, 1), Pseq(~ch2_bufArray.(list: ~ch2_pseq_entry.split($,).asFloat), 1)], 1);
				~patterns.value();
			});
		};
		);
		if (~sourceCheckbox1.value == true || ~sourceCheckbox2.value == true && ~channelButton3.value == 1, {
			if (~ch3_styleMenu.value == 0, {
				~ch3_pseq_buf = Pseq(~ch3_bufArray.(list: ~ch3_pseq_entry.split($,).asFloat), 1);
				~patterns.value();
			});
			if (~ch3_styleMenu.value == 1, {
				~ch3_pseq_buf = Pseq([Pseq(~ch3_bufArray.(list: ~ch3_pseq_entry.split($,).asFloat), 1), Pseq(~ch3_bufArray.(list: ~ch3_pseq_entry.split($,).asFloat).reverse, 1)], 1);
				~patterns.value();
			});
			if (~ch3_styleMenu.value == 2, {
				~ch3_pseq_buf = Pseq(~ch3_bufArray.(list: ~ch3_pseq_entry.split($,).asFloat).reverse, 1);
				~patterns.value();
			});
			if (~ch3_styleMenu.value == 3, {
				~ch3_pseq_buf = Pseq([Pseq(~ch3_bufArray.(list: ~ch3_pseq_entry.split($,).asFloat).reverse, 1), Pseq(~ch3_bufArray.(list: ~ch3_pseq_entry.split($,).asFloat), 1)], 1);
				~patterns.value();
			});
		};
		);
	}.value();
)};
);
~switches.value();
)

// Pattern
(
(
~patterns = {(
	(
		Pdef(\a64, Pbind(
			\instrument, \mainbuf, \group, ~sources,
			\patch, ~patch1,
			\amp, 1,
			\dur, 6,
			\atk, 0.011,
			\rel, 6.10333984212,
			\rate, 1,
			\pos, 1,
			\bank, Pseq([~ch1_pseq_buf], inf),
		)).quant_(4);
	);
	Pdef(\a64).play(t, quant:4);
	//Pdef(\a64).stop(t, quant:4);
);
};
);
~patterns.value();
)