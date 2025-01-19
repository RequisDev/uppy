defmodule Uppy.Schedulers.ObanScheduler.Workers.AbortExpiredMultipartUploadWorker do
  @max_attempts 10

  @moduledoc """
  Aborts non-multipart and multipart uploads that have not
  been completed after a set amount of time.
  """
  use Oban.Worker,
    queue: :abort_expired_multipart_upload,
    max_attempts: @max_attempts,
    unique: [
      period: 300,
      states: [:available, :scheduled, :executing]
    ]

  alias Uppy.{
    Core,
    Schedulers.ObanScheduler.CommonAction
  }

  @event_abort_expired_multipart_upload "uppy.abort_expired_multipart_upload"

  def perform(%{attempt: @max_attempts, args: args}) do
    CommonAction.insert(__MODULE__, args, [])
  end

  def perform(%{
    args:
      %{
        "event" => @event_abort_expired_multipart_upload,
        "bucket" => bucket,
        "id" => id
      } = args
  }) do
    with {:error, %{code: :not_found}} <-
           Core.abort_multipart_upload(
             bucket,
             CommonAction.get_args_query(args),
             %{id: id},
             %{status: :expired},
             []
           ) do
      {:ok, "skipping - object or record not found"}
    end
  end

  def queue_abort_expired_multipart_upload(bucket, query, id, opts) do
    params =
      query
      |> CommonAction.query_to_args()
      |> Map.merge(%{
        event: @event_abort_expired_multipart_upload,
        bucket: bucket,
        id: id
      })

    CommonAction.insert(__MODULE__, params, opts)
  end
end