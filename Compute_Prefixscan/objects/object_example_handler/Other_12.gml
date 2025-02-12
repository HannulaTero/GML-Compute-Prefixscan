/// @desc SCAN WITH CUSTOM PIPELINE.


custom.adapter = GPU.requestAdapter();
custom.device = custom.adapter.requestDevice();


// Using custom pipeline.
custom.scan = new Prefixscan({
  device: custom.device, 
  workgroupSize: 256,
  operation: "(lhs + rhs)",
  dtype: "f32",
  dsize: 4,
});


// Create GPU input and output buffers.
custom.input = custom.device.createBuffer({ 
  label: "Prefixscan Storage Input",
  usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST,
  size: buffer.bytes, 
});

custom.output = custom.device.createBuffer({ 
  label: "Prefixscan Storage Output",
  usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST,
  size: buffer.bytes,
});

// Output can't be read directly, needs intermediate buffer.
custom.staging = custom.device.createBuffer({ 
  label: "Prefixscan Staging Buffer",
  usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST,
  size: buffer.bytes, 
});


// Executing.
custom.Execute = function()
{
  Log($"Dispatching scan from Custom Pipeline...");
  
  // Move inputs from CPU to GPU.
  TimerBegin("Time of full dispatch");
  TimerBegin("Move inputs to GPU");
  custom.device.queue.writeBuffer(custom.input, 0, buffer.input, 0, buffer.bytes);
  TimerEnd();
  
  // Compute and get he results.
  TimerBegin("Dispatch Custom Pipeline");
  custom.scan.Dispatch(custom.output, custom.input, 0, itemCount);
  TimerEnd();
  
  // Copy the results to staging buffer.
  TimerBegin("Copy output to staging");
  var _encoder = custom.device.createCommandEncoder();
  _encoder.copyBufferToBuffer(custom.output, 0, custom.staging, 0, buffer.bytes);
  custom.device.queue.submit([ _encoder.finish() ]);
  TimerEnd();
  
  
  // Read the results.
  TimerBegin("Map outputs for reading");
  custom.staging.mapAsync(GPUMapMode.READ, function(_status, _buffer)
  {
    // Have been mapped.
    TimerEnd();
      
    // If there has been an error.
    if (_status != GPUBufferMapAsyncStatus.SUCCESS)
    {
      static errorCases = [
        "Instance dropped",
        "Validation error",
        "Unknown error",
        "Device lost",
        "Destroyed before callback",
        "Unmapped before callback",
        "Offset out of range",
        "Size out of range",
        "Undefined case",
      ];
      Log($"MapAsync: {errorCases[_status]}.");
      TimerEnd();
      TimerEnd();
      Log($"Dispatching Custom Pipeline failed!");
      return;
    }
    Log("MapAsync: Success!");
    
    // Get the results into CPU.
    TimerBegin("Read the outputs");
    _buffer.getMappedRange().toBuffer(buffer.output, 0, buffer.bytes, 0);
    _buffer.unmap();
    TimerEnd();
    TimerEnd();

    // Get the results.
    Log($"Dispatching Custom Pipline finished!");
    Slice();
  });
};



