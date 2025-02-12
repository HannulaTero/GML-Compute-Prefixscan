
randomize();


// Logging.
log = [];
slice = {};
slice.count = 36;
slice.index = [];
slice.input = [];
slice.output = [];
timers = [];


// Dispatching options.
itemCount = 1024.0 * 1024.0;
inputRange = [ 0.0, 1.0 ];
workgroupSize = 256.0;


// Create buffers for storing inputs and outputs in CPU.
buffer = {};
buffer.bytes = buffer_sizeof(buffer_f32) * itemCount;
buffer.input = buffer_create(buffer.bytes, buffer_fixed, 1);
buffer.output = buffer_create(buffer.bytes, buffer_fixed, 1);


// Declare Helper methdos, defined in user-events.
Log = undefined;
Randomize = undefined;
Slice = undefined;
TimerBegin = undefined;
TimerEnd = undefined;


// Declare Compute API and Custom Pipeline.
compute = {};
custom = {};


// Define helpers and computes.
event_perform(ev_other, ev_user0);
event_perform(ev_other, ev_user1);
event_perform(ev_other, ev_user2);

