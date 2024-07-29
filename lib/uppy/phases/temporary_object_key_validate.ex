defmodule Uppy.Phases.TemporaryObjectKeyValidate do
  @moduledoc """
  ...
  """
  alias Uppy.{TemporaryObjectKey, Utils}

  @type input :: map()
  @type options :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Adapter.Phase

  @logger_prefix "Uppy.Phases.TemporaryObjectKeyValidate"

  @impl Uppy.Adapter.Phase
  @doc """
  Implementation for `c:Uppy.Adapter.Phase.run/2`
  """
  @spec run(input(), options()) :: t_res(input())
  def run(
        %Uppy.Pipeline.Input{
          schema_data: schema_data
        } = input,
        options
      ) do
    Utils.Logger.debug(@logger_prefix, "RUN BEGIN", binding: binding())

    with {:ok, _} <- TemporaryObjectKey.validate(schema_data.key, options) do
      {:ok, input}
    end
  end
end
