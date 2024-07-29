defmodule Uppy.Pipeline.Phase.TemporaryObjectKeyValidate do
  @moduledoc """
  Validates the `key` on the `schema_data` is a temporary object key.
  """
  alias Uppy.{TemporaryObjectKey, Utils}

  @type input :: map()
  @type options :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Adapter.Pipeline.Phase

  @logger_prefix "Uppy.Pipeline.Phase.TemporaryObjectKeyValidate"

  @impl Uppy.Adapter.Pipeline.Phase
  @doc """
  Implementation for `c:Uppy.Adapter.Pipeline.Phase.run/2`
  """
  @spec run(input(), options()) :: t_res(input())
  def run(
    %Uppy.Pipeline.Input{
      value: %{schema_data: schema_data},
      options: runtime_options
    } = input,
    phase_options
  ) do
    Utils.Logger.debug(@logger_prefix, "run BEGIN", binding: binding())

    options = Keyword.merge(phase_options, runtime_options)

    with {:ok, _} <- TemporaryObjectKey.validate(schema_data.key, options) do
      {:ok, input}
    end
  end
end
