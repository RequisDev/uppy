defmodule Uppy.Phases.PutImageProcessorResult do
  @moduledoc """
  ...
  """

  alias Uppy.{
    PathBuilder,
    Utils
  }

  @type input :: map()
  @type schema :: Ecto.Queryable.t()
  @type schema_data :: Ecto.Schema.t()
  @type params :: map()
  @type options :: keyword()

  @type t_res(t) :: {:ok, t} | {:error, term()}

  @behaviour Uppy.Adapter.Phase

  @logger_prefix "Uppy.Phases.PutImageProcessorResult"

  @default_resource "uploads"

  @one_thousand_twenty_four 1_024

  @five_megabytes 5_242_880

  def run(
    %Uppy.Pipeline.Input{
      bucket: bucket,
      schema_data: schema_data,
      holder: holder,
      context: context
    } = input,
    options
  ) do
    Utils.Logger.debug(@logger_prefix, "run BEGIN")

    file_info = context.file_info

    metadata = context.metadata

    if phase_completed?(context) or !supported_image?(file_info, metadata, options) do
      Utils.Logger.debug(@logger_prefix, "skipping execution because phase already completed or the object is not a support image")

      {:ok, input}
    else
      Utils.Logger.debug(@logger_prefix, "copying optimized image result")

      with {:ok, destination_object} <-
        put_permanent_result(bucket, holder, schema_data, options) do
        Utils.Logger.debug(@logger_prefix, "copied image to #{inspect(destination_object)}")

        {:ok, %{input | context: Map.put(context, :destination_object, destination_object)}}
      end
    end
  end

  defp phase_completed?(%{destination_object: _}), do: true
  defp phase_completed?(_), do: false

  defp width_and_height_less_than_max?(%{width: width, height: height}, options) do
    max_image_width = options[:max_image_width] || @one_thousand_twenty_four
    max_image_height = options[:max_image_height] || @one_thousand_twenty_four

    (width <= max_image_width) and (height <= max_image_height)
  end

  defp has_width_and_height?(%{width: _, height: _}), do: true
  defp has_width_and_height?(_), do: false

  defp image_size_less_than_max?(%{content_length: content_length}, options) do
    max_image_size = options[:max_image_size] || @five_megabytes

    content_length <= max_image_size
  end

  defp supported_image?(file_info, metadata, options) do
    has_width_and_height?(file_info) and
    width_and_height_less_than_max?(file_info, options) and
    image_size_less_than_max?(metadata, options)
  end

  def put_permanent_result(bucket, %_{} = holder, %_{} = schema_data, options) do
    holder_id = Uppy.Holder.fetch_id!(holder, options)
    resource = resource!(options)
    basename = Uppy.Core.basename(schema_data)

    source_object = schema_data.key

    destination_object =
      PathBuilder.permanent_path(
        %{
          id: holder_id,
          resource: resource,
          basename: basename
        },
        options
      )

    params = options[:image_processor_parameters] || %{}

    with {:ok, _} <-
      Uppy.ImageProcessor.put_result(
        bucket,
        source_object,
        params,
        destination_object,
        options
      ) do
      {:ok, destination_object}
    end
  end

  defp resource!(options) do
    with nil <- Keyword.get(options, :resource, @default_resource) do
      raise "option `:resource` cannot be `nil` for phase #{__MODULE__}"
    end
  end
end