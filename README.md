At the moment, in order to use this, you'll have to first initiate each major function.

```
~tempo.value();
~patches.value();
~synthdefs.value();
~buffers.value();

~gui.value();
~midi.value();
~switches.value();
~patterns.value();
```

Additionally, you will have to execute this block independently.

```
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
```

Once that is done, Cmmd+. to reset the node tree, then press the main function caller at the top of the file.