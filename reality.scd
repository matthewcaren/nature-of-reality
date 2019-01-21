/*
------- ON THE NATURE OF REALITY -------
----------- by Matthew Caren -----------

a panic attack in multichannel audio
for 8 speaker ring numbered clockwise - "front" bisects channel 8 and channel 1
*/

// set up 8 output channels
o = Server.default.options;
o.numOutputBusChannels = 8;
s = Server.default.boot;


(
// -- ON START --


// connect all midi devices
MIDIIn.connectAll;

~stretch = 1.414;
~root = 250;

// creates an array of equal tempered scale ratios (to be stretched later)
f = {|steps| Array.fill(steps, {|i| 2.pow(i/steps)})};

~et12 = f.(12);
~et24 = f.(24);

// return a freq given scale, stretch factor, degree
~freqCaluculator = { arg note, scale;
	if(scale == ~et12, {
		(~root * scale.linlin(1, 2, 1, ~stretch))[note];
	}, {
		(~root * scale.linlin(1, 2, 1, ~stretch*2))[note];
	})
};

// create effect bus
~effectBus = Bus.audio;


// load buffers
~babblingChild = Buffer.read(s, Platform.resourceDir +/+ "sounds/a11wlk01.wav");
~getout = Buffer.read(s, thisProcess.nowExecutingPath.dirname +/+ "samples/get_out.wav");
~announcement = Buffer.read(s, thisProcess.nowExecutingPath.dirname +/+ "samples/announcement.wav");
~footsteps = Buffer.read(s, thisProcess.nowExecutingPath.dirname +/+ "samples/breathing excercise.wav");
~ending = Buffer.read(s, thisProcess.nowExecutingPath.dirname +/+ "samples/ending.wav");
)


(
// SYNTHDEFS

// sine + noise
SynthDef("quick2", {arg freq = 440, amp = 0.1, gate = 1;
	var snd, env;
	env = Env.adsr(0.05, 0.2, 0.7, 1, amp).kr(2, gate);
	snd = SinOsc.ar(freq: freq, mul: env * 0.75);
	snd = snd + (BrownNoise.ar(0.005 * env));
	snd = PanAz.ar(8, snd, Saw.kr(0.1));
	Out.ar(0, snd)
}).add;

// random additive synthesis
SynthDef("bell", {arg freq = 440, amp = 0.1, pan = 0;
	var snd, env;
	env = Env.perc(0.01, 2.5, amp).kr(2);
	snd = LFPar.ar(
		freq: freq*[1, ~stretch*1.2, ~stretch*1.5, ~stretch*2, ~stretch*4],
		mul: env * [1, 0.4, 0.3, 0.2, 0.05, 0.05] * 0.1
	);

	snd = Mix.ar(snd);

	snd = FreeVerb(snd, 0.5, 1);

	snd = PanAz.ar(8, snd, pan);

	Out.ar(~effectBus, snd);
}).add;

// square + lowpass
SynthDef("bass", {arg freq = 440, amp = 0.8, pan = 0;
	var snd, env, env2;
	env = Env.perc(0.05, 0.8, amp).kr(2);
	env2 = Env.perc(0.3, 1, amp).kr(2);
	snd = Pulse.ar([freq/~stretch.squared, freq/~stretch.squared.squared]);
	snd = snd + SinOsc.ar(freq/~stretch.squared.squared);
	snd = snd * env;
	snd = BLowPass.ar(snd, env2.range(10, 150), 0.4);
	snd = (snd * 100).tanh * 0.05;
	Out.ar(~effectBus, snd !8);
}).add;

// sine w/ long attack/rel
SynthDef("pulse", {arg freq = 440, amp = 0.1, gate = 1;
	var snd, env;
	env = Env.adsr(0.2, 0.2, 0.7, 2, amp).kr(2, gate);
	snd = SinOsc.ar(freq: freq, mul: env * 0.7);
	snd = snd/8;
	Out.ar(~effectBus, snd!8)
}).add;

// saw long attack
SynthDef("reverse", {arg freq = 440, amp = 0.1, gate = 1;
	var snd, env, pan;
	env = Env.adsr(2, 0.2, 0.7, 0.01, amp).kr(2, gate);
	snd = Saw.ar(freq: freq, mul: env);

	snd = PanAz.ar(8, snd, Rand(-1, 1.0));

	Out.ar(~effectBus, snd)
}).add;

// dust through resonant lowpass
SynthDef("dust", { arg freq = 600;
    var snd;

	snd = RLPF.ar(Dust.ar(Line.kr(15!8, 0, 2, doneAction: 2), LFNoise1.ar(0.5!8).range(100, 3000), 0.1), freq, mul: 0.01);

	snd = snd/4;

	Out.ar(~effectBus, snd)
}).add;

// fm w/ lfnoise
SynthDef("bubbles", {
    var freq, freq2, env, snd;
    freq = Formlet.kr(
        Dust.kr(10 ! 2),
		LFNoise1.kr.range(-1, 1, 7, 200),
        0.005, 0.5
    );

	freq2 = Formlet.kr(
        Dust.kr(10 ! 2),
		LFNoise1.kr.range(-1, 1, 7, 200),
        0.005, 0.5
    );

	snd = SinOsc.ar(freq * 200 + 300 * SinOsc.ar(freq2 * 200)) * 0.2;

	snd = snd/4;

	Out.ar(~effectBus, snd!8);
}).add;

// skip through default SC sample
SynthDef(\child, {| fade = 0, pitch = 1 |
    var rate, snd;
	rate = LFNoise0.kr(3, 2).range(-1 * pitch, pitch);

	snd = PlayBuf.ar(1, ~babblingChild, BufRateScale.kr(~babblingChild) * rate, 1, 0, 1) * 0.15;

	snd = PanAz.ar(8, snd, LFNoise1.kr(2));

	Out.ar(~effectBus, snd)
}).add;

// skip through speech sample
SynthDef(\getout, {| fade = 0 |
    var rate, snd;
    rate = LFNoise0.kr(2.3, 2);

	snd = PlayBuf.ar(1, ~getout, BufRateScale.kr(~getout) * rate, 1, 0, 1) * 0.6;

	snd = PanAz.ar(8, snd, LFNoise1.kr(1));

	Out.ar(~effectBus, snd)
}).add;

// same, but only forward
SynthDef(\getoutF, {| fade = 0 |
    var rate, snd;
	rate = LFNoise0.kr(10, 2).range(Line.kr(0.4, 1.3, 2), Line.kr(0.6, 1.5, 2));

	snd = PlayBuf.ar(1, ~getout, BufRateScale.kr(~getout) * rate, 1, 0, 0, doneAction: 2);

	snd = snd/8;

	Out.ar(~effectBus, snd!8)
}).add;

// other samples
SynthDef(\announcement, {| fade = 0 |
    var snd, rate;

	rate = LFNoise0.kr(2, 2);

	snd = PlayBuf.ar(1, ~announcement, BufRateScale.kr(~announcement) * rate, 1, 0, 1) * 0.7;

	snd = snd/6;

    Out.ar(~effectBus, snd!8)
}).add;

SynthDef(\ending, {| fade = 0 |
	var snd;

    snd = PlayBuf.ar(1, ~ending, BufRateScale.kr(~ending), 1, 0, 1) * 0.7;

	snd = snd/6;

    Out.ar(0, snd!8)
}).add;

// pan sample in a circle
SynthDef(\footsteps, {
    var snd;

	snd = PlayBuf.ar(1, ~footsteps, BufRateScale.kr(~footsteps), 1, 0, 0) * 0.2;

	snd = PanAz.ar(8, snd, LFSaw.kr(0.05).range(-1, 1));

    Out.ar(~effectBus, snd)
}).add;

// snare (2 sins, noise)
SynthDef(\neurosnare, {
    var snd;
    // a percussive click to give it some attack
    snd = LPF.ar(HPF.ar(WhiteNoise.ar, 300), 8000) * Env.linen(0.001, 0.01, 0.001).ar;
    // sine sweep body. very important!
    snd = snd + (SinOsc.ar(Env([400, 196, 160], [0.04, 0.2], \exp).ar) * Env.perc(0.04, 0.2).ar * 6.dbamp).tanh;
    // sound of snare coils rattling
    snd = snd + (HPF.ar(BPeakEQ.ar(WhiteNoise.ar, 4000, 0.5, 3), 300) * Env.perc(0.05, 0.2).delay(0.01).ar(2) * -3.dbamp);
    // another sound sweep to improve the attack, optional
    snd = snd + (SinOsc.ar(XLine.kr(3000, 1500, 0.01)) * Env.perc(0.001, 0.02).ar);
    // distortion helps glue everything together and acts as a compressor
    snd = (snd * 2).tanh;
    snd = PanAz.ar(8, snd, \pan.kr(0), \amp.kr(0.2));
    Out.ar(~effectBus, snd);
}).add;

// kick - sin w/ env controlling pitch
SynthDef(\kick, { arg rel = 1;
    var snd;
	snd = SinOsc.ar(
		freq: Line.kr(85, 35, rel),
		mul: Env.perc(
			attackTime: 0.02,
			releaseTime: rel
		).kr(doneAction: 2)
	);

	snd = (snd * 1.5).tanh;

	snd = snd/2;

	Out.ar(~effectBus, snd!8);
}).add;

// hihat-ish - filtered noise
SynthDef(\hat, {arg amp = 0.5, att = 0.01, rel = 0.2, ffreq = 6000, pan = 0;
	var env, snd;
	env = Env.perc(att, rel, amp).kr(doneAction: 2);
	snd = WhiteNoise.ar;
	snd = HPF.ar(in: snd, freq: ffreq, mul: env);
	Out.ar(~effectBus, PanAz.ar(8, snd, pan));
}).add;

// blip
SynthDef(\tick, {arg pan = 0;
	var env, snd;
	env = Env.perc(0.001, 0.01, 0.8).kr(doneAction: 2);
	snd = WhiteNoise.ar;
	snd = BPF.ar(in: snd, freq: 300, mul: env);
	Out.ar(~effectBus, PanAz.ar(8, snd, pan));
}).add;


// everything runs through an effect bus - for clipping, amp control
(
~clip = { arg limit = 1, amp = 1;
	var snd;
	snd = In.ar(~effectBus, 8) * 0.5;
	limit = Lag.kr(limit, 12);
	amp = Lag.kr(amp, 12);
	snd = Clip.ar(snd, -1 * limit, limit) * amp;
	Out.ar(0, snd);
}.play;
)
)



(
// tempoclock initialization
t = TempoClock.new(4/5);

~droneSub = Pbind(
	\freq, ~root/[~stretch.squared.squared, ~stretch.squared.cubed],
	\amp, 0.5,
	\dur, Pseq([16], 1),
	\instrument, \quick2
);

~droneLow = Pbind(
	\freq, ~root/~stretch.cubed,
	\amp, 0.5,
	\dur, Pseq([16], 1),
	\instrument, \quick2
);


~droneAlt = Pbind(
	\freq, ~root * ~stretch * 5/12,
	\amp, 0.1,
	\dur, Pseq([16], 1),
	\instrument, \quick2
);

~droneMid = Pbind(
	\freq, ~root/~stretch.squared,
	\amp, 0.1,
	\dur, Pseq([16], 1),
	\instrument, \quick2
);

~pulse = Pbind(
	\freq, ~root,
	\amp, 0.1,
	\dur, Pn(4, 4),
	\legato, 0.5,
	\instrument, \pulse
);

~reverse = Pbind(
	\freq, Pxrand(~freqCaluculator.value((0..23), ~et24), inf),
	\amp, 0.4,
	\dur, Pn(1/8, 128),
	\legato, 0.5,
	\instrument, \reverse,
);

~bells = Pbind(
	\freq, Pxrand(~freqCaluculator.value((0..23), ~et24), inf),
	\amp, 0.4,
	\dur, Pshuf([1.2, 0.8, 0.6, 0.4, 0.4, 0.4, 0.2], 4),
	\legato, 0.5,
	\instrument, \bell,
	\pan, Pwhite(-1.0, 1.0),
);

// ---

~theme1 = Pbind(
	\freq, Pseq(~freqCaluculator.value(
		[
			7, 5, 8, 6, 3, 1, 5,
			7, 5, 8, 6, 2, 1, 0
		],
		~et24), inf) * ~stretch,
	\amp, 0.05,
	\dur, Pseq([1.7, 0.3, 1, 0.6, 0.4, 2, 2], 2),
	\instrument, \quick2
);

~theme2 = Pbind(
	\freq, Pseq(~freqCaluculator.value(
		[
			7, 5, 8, 6, 9, 12, 11,
			10, 6, 4, 3, 5, 0, 0,
		],
		~et24), inf) * ~stretch,
	\amp, 0.1,
	\dur, Pseq([1.7, 0.3, 1, 0.6, 0.4, 2, 2], 2),
	\instrument, \quick2
);

~theme2cp = Pbind(
	\freq, Pseq(~freqCaluculator.value(
		[
			7, 5, 8, 6, 9, 12, 11,
			10, 6, 4, 3, 5, 0, 0,
		],
		~et24), inf) * ~stretch.squared * 7/12,
	\amp, 0.1,
	\dur, Pseq([1.7, 0.3, 1, 0.6, 0.4, 2, 2], 2),
	\instrument, \quick2
);

~themeAlt = Pbind(
	\freq, Pseq(~freqCaluculator.value(
		[
			7, 5, 8, 6, 9, 12, 11,
			10, 6, 4, 3, 5, 0, 0,
		],
		~et24), inf) * ~stretch.squared,
	\amp, 0.05,
	\dur, Pseq([1.7, 0.3, 1, 0.6, 0.4, 2, 2], 2),
	\instrument, \quick2
);

~dust = Pbind(
	\freq, Pwhite(200, 900),
	\amp, 0.1,
	\dur, 2,
	\instrument, \dust
);

~bubbles = Pbind(
	\dur, Pseq([1]),
	\instrument, \bubbles
);

~snare = Pbind(
	\amp, 0.1,
	\dur, Pseq([Rest(1), 1], 8),
	\instrument, \neurosnare,
	\pan, Pwhite(-1, 1);
);

~kick = Pbind(
	\dur, Pseq([3.9, 0.1], 4),
	\rel, Pseq([1, 0.05], inf),
	\instrument, \kick
);

~hat = Pbind(
	\dur, Pshuf([0.1, 0.1, 0.2, 0.3, 0.3, 1], 8),
	\instrument, \hat,
	\pan, Pwhite(-1.0, 1.0),
	\rel, Prand([0.02, 0.05, 0.1, 0.2, 0.5, 1], inf);
);

~tick = Pbind(
	\dur, Pn(1, 16),
	\instrument, \tick,
	\pan, Pseq([-1, 1], inf),
);

~bass = Pbind(
	\freq, Pseq(~freqCaluculator.value([
		12, 1, 14, 9, 7, 6,
		10, 8, 7, 8, 3, 4,
		12, 1, 14, 15, 16, 17,
		18, 8, 7, 5, 5, 0
	],~et24), inf) / ~stretch,
	\dur, Pseq([0.5, 0.5, 3], 4),
	\instrument, \bass
);

)



// main control
(
Pspawner({ arg maestro;

	~clip.set(\limit, 1);
	~clip.set(\amp, 1);

	Synth(\footsteps);

	maestro.wait(10);

	~murmuring = Synth(\getout);
	maestro.wait(8);

	maestro.seq(~pulse);

	~babbling = Synth(\child, [\pitch: 1.1]);
	maestro.par(~theme1);
	maestro.seq(~pulse);
	~babbling.free;

	~babbling = Synth(\child, [\pitch: 0.7]);
	maestro.par(~theme2);
	maestro.par(~droneMid);
	maestro.par(~child);
	maestro.seq(~pulse);
	~babbling.free;


	~babbling = Synth(\child, [\pitch: 0.5]);
	~duster = maestro.par(~dust);
	maestro.par(~themeAlt);
	maestro.par(~droneAlt);
	maestro.seq(~pulse);
	maestro.suspend(~duster);
	~murmuring.free;
	~babbling.free;

	maestro.wait(1);

	~duster = maestro.par(~dust);
	~bubbling = Synth(\bubbles);
	~murmuring = Synth(\getout);
	~murmuring2 = Synth(\getout);
	~babbling = Synth(\child);
	maestro.par(~reverse);
	maestro.par(~kick);
	maestro.par(~droneMid);
	maestro.par(~droneLow);
	maestro.par(~theme1);
	maestro.seq(~pulse);

	~clip.set(\amp, 1.1);

	maestro.suspend(~duster);
	maestro.suspend(~bubbly);
	~babbling.free;
	~bubbling.free;
	~murmuring.free;
	~murmuring2.free;

	~clip.set(\amp, 1);

	Synth(\getoutF);
	maestro.wait(5);

	~duster = maestro.par(~dust);
	~bubbling = Synth(\bubbles);
	~murmuring = Synth(\getout);
	~murmuring2 = Synth(\getout);
	~babbling = Synth(\child);
	~pa = Synth(\announcement);
	maestro.par(~reverse);
	maestro.par(~kick);
	maestro.par(~snare);
	maestro.par(~hat);
	maestro.par(~droneMid);
	maestro.par(~droneLow);
	maestro.par(~droneSub);
	maestro.par(~theme1);
	maestro.par(~bells);
	maestro.seq(~pulse);

	maestro.par(~reverse);
	maestro.par(~kick);
	maestro.par(~snare);
	maestro.par(~hat);
	maestro.par(~droneMid);
	maestro.par(~droneLow);
	maestro.par(~droneSub);
	maestro.par(~theme2);
	maestro.par(~theme2cp);
	maestro.par(~bass);
	maestro.par(~bells);
	maestro.seq(~pulse);

	~clip.set(\limit, 0.2);
	~clip.set(\amp, 1.15);

	maestro.par(~reverse);
	maestro.par(~kick);
	maestro.par(~snare);
	maestro.par(~hat);
	maestro.par(~droneMid);
	maestro.par(~droneLow);
	maestro.par(~droneSub);
	maestro.par(~theme2);
	maestro.par(~theme2cp);
	maestro.par(~bass);
	maestro.par(~bells);
	maestro.seq(~pulse);

	~clip.set(\limit, 0.01);
	~clip.set(\amp, 1.3);

	maestro.par(~reverse);
	maestro.par(~kick);
	maestro.par(~snare);
	maestro.par(~hat);
	maestro.par(~droneMid);
	maestro.par(~droneLow);
	maestro.par(~droneSub);
	maestro.par(~theme2);
	maestro.par(~theme2cp);
	maestro.par(~bass);
	maestro.par(~bells);
	maestro.seq(~pulse);

	maestro.seq(~kick);

	maestro.wait(5);

	~duster.free;
	~bubbling.free;
	~murmuring.free;
	~murmuring2.free;
	~babbling.free;
	~pa.free;

	Synth(\ending);

}).play;
)