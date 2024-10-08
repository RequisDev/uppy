defmodule Uppy.Phases.HeadTemporaryObject do
  @moduledoc """
  ...
  """
  alias Uppy.{Storage, Utils}

  @behaviour Uppy.Phase

  @logger_prefix "Uppy.Phases.HeadTemporaryObject"

  def run(
    %Uppy.Resolution{
      bucket: bucket,
      value: schema_data,
      context: context
    } = resolution,
    opts
  ) do
    Utils.Logger.debug(@logger_prefix, "run BEGIN")

    case Storage.head_object(bucket, schema_data.key, opts) do
      {:ok, metadata} ->
        Utils.Logger.debug(@logger_prefix, "run OK")

        {:ok, %{resolution | context: Map.put(context, :metadata, metadata)}}

      error ->
        Utils.Logger.debug(@logger_prefix, "run ERROR")

        error
    end
  end
end
