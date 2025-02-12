/// @desc SCAN WITH COMPUTE API.


// Using simplification layer.
compute.scan = new ComputeScan({
  workgroupSize: 256,
  operation: "(lhs + rhs)", 
  dtype: "f32",
  dsize: 4,
});


// Create GPU buffers.
compute.input = new ComputeBuffer( buffer.bytes, false, true );
compute.output = new ComputeBuffer( buffer.bytes, true, false );


// Executing.
compute.Execute = function()
{
  Log($"Dispatching scan from Compute API...");
  
  // Move inputs from CPU to GPU.
  TimerBegin("Time of full dispatch");
  TimerBegin("Move inputs to GPU");
  compute.input.fromBuffer( buffer.input );
  TimerEnd();

  // Compute and get he results.
  TimerBegin("Dispatch Compute API");
  compute.scan.Dispatch( compute.output, compute.input, 0, itemCount );
  TimerEnd();
  
  // Print slice of results.
  TimerBegin("Read the outputs");
  compute.output.toBuffer( buffer.output, 0, buffer.bytes, 0 );
  TimerEnd();
  TimerEnd();
  
  // Get the results.
  Log($"Dispatching Compute API finished!");
  Slice();
};