defmodule Uppy.Scheduler do
  alias Uppy.Config

  @default_scheduler_adapter Uppy.Schedulers.Oban

  def queue_delete_object_if_upload_not_found(
        bucket,
        schema,
        key,
        schedule_at_or_schedule_in,
        options
      ) do
    bucket
    |> adapter!(options).queue_delete_object_if_upload_not_found(
      schema,
      key,
      schedule_at_or_schedule_in,
      options
    )
    |> handle_response()
  end

  def queue_abort_multipart_upload(
        bucket,
        schema,
        id,
        schedule_at_or_schedule_in,
        options
      ) do
    bucket
    |> adapter!(options).queue_abort_multipart_upload(
      schema,
      id,
      schedule_at_or_schedule_in,
      options
    )
    |> handle_response()
  end

  def queue_abort_upload(
        bucket,
        schema,
        id,
        schedule_at_or_schedule_in,
        options
      ) do
    bucket
    |> adapter!(options).queue_abort_upload(
      schema,
      id,
      schedule_at_or_schedule_in,
      options
    )
    |> handle_response()
  end

  def queue_process_upload(
        pipeline_module,
        bucket,
        resource_name,
        schema,
        id,
        nil_or_schedule_at_or_schedule_in,
        options
      ) do
    pipeline_module
    |> adapter!(options).queue_process_upload(
      bucket,
      resource_name,
      schema,
      id,
      nil_or_schedule_at_or_schedule_in,
      options
    )
    |> handle_response()
  end

  defp adapter!(options) do
    Keyword.get(options, :scheduler_adapter, Config.scheduler_adapter()) ||
      @default_scheduler_adapter
  end

  defp handle_response({:ok, _} = ok), do: ok
  defp handle_response({:error, _} = error), do: error

  defp handle_response(term) do
    raise """
    Expected one of:

    `{:ok, term()}`
    `{:error, term()}`

    got:
    #{inspect(term, pretty: true)}
    """
  end
end