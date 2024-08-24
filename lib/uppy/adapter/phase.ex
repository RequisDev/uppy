defmodule Uppy.Adapter.Phase do

  @type t :: module() | {module(), keyword()}

  @type input :: term()

  @type options :: Uppy.options()

  @callback run(input :: map(), options :: keyword()) :: term()
end
