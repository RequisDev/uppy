defmodule Uppy.Adapter.Pipeline.Phase do
  @callback run(input :: map(), opts :: keyword()) :: term()
end