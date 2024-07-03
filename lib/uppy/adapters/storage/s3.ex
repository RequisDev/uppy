if Uppy.Utils.ensure_all_loaded?([ExAws, ExAws.S3]) do
  defmodule Uppy.Adapters.Storage.S3 do
    @moduledoc """
    Implements the `Uppy.Adapter.Storage` behaviour.
    """
    alias Uppy.Utils

    @behaviour Uppy.Adapter.Storage

    @is_prod Mix.env() === :prod

    @impl true
    @doc """
    Implementation for `c:Uppy.Adapter.Storage.list_objects/2`.
    """
    def list_objects(bucket, prefix \\ "", options \\ []) do
      s3_options = Keyword.put(options, :prefix, prefix)

      bucket
      |> ExAws.S3.list_objects_v2(s3_options)
      |> ExAws.request(options)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Adapter.Storage.get_object/3`.
    """
    def get_object(bucket, object, options \\ []) do
      bucket
      |> ExAws.S3.get_object(object, options)
      |> ExAws.request(options)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Adapter.Storage.head_object/3`.
    """
    def head_object(bucket, object, options \\ []) do
      bucket
      |> ExAws.S3.head_object(object, options)
      |> ExAws.request(options)
      |> deserialize_headers()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Adapter.Storage.presigned_part_upload/5`.
    """
    def presigned_part_upload(bucket, object, upload_id, part_number, options \\ []) do
      query_params = %{
        "uploadId" => upload_id,
        "partNumber" => part_number
      }

      options = Keyword.update(options, :query_params, query_params, &Map.merge(&1, query_params))

      presigned_upload(bucket, object, options)
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Adapter.Storage.presigned_download/3`.
    """
    def presigned_download(bucket, object, options \\ []) do
      presigned_url(bucket, :get, object, options)
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Adapter.Storage.presigned_upload/3`.
    """
    def presigned_upload(bucket, object, options \\ []) do
      options = Keyword.put_new(options, :s3_accelerate, @is_prod)

      presigned_url(bucket, :put, object, options)
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Adapter.Storage.presigned_url/4`.
    """
    def presigned_url(bucket, method, object, options \\ []) do
      :s3
      |> ExAws.Config.new(options)
      |> ExAws.S3.presigned_url(method, bucket, object, options)
      |> handle_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Adapter.Storage.list_multipart_uploads/2`.
    """
    def list_multipart_uploads(bucket, options \\ []) do
      bucket
      |> ExAws.S3.list_multipart_uploads(options)
      |> ExAws.request(options)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Adapter.Storage.initiate_multipart_upload/3`.
    """
    def initiate_multipart_upload(bucket, object, options \\ []) do
      bucket
      |> ExAws.S3.initiate_multipart_upload(object)
      |> ExAws.request(options)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Adapter.Storage.list_parts/4`.
    """
    def list_parts(bucket, object, upload_id, next_part_number_marker \\ nil, options \\ []) do
      options =
        if next_part_number_marker do
          query_params = %{"part-number-marker" => next_part_number_marker}
          Keyword.update(options, :query_params, query_params, &Map.merge(&1, query_params))
        else
          options
        end

      bucket
      |> ExAws.S3.list_parts(object, upload_id, options)
      |> ExAws.request(options)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Adapter.Storage.abort_multipart_upload/4`.
    """
    def abort_multipart_upload(bucket, object, upload_id, options \\ []) do
      bucket
      |> ExAws.S3.abort_multipart_upload(object, upload_id)
      |> ExAws.request(options)
      |> handle_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Adapter.Storage.complete_multipart_upload/5`.
    """
    def complete_multipart_upload(bucket, object, upload_id, parts, options \\ []) do
      bucket
      |> ExAws.S3.complete_multipart_upload(object, upload_id, parts)
      |> ExAws.request(options)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Adapter.Storage.put_object_copy/5`.
    """
    def put_object_copy(dest_bucket, dest_object, src_bucket, src_object, options \\ []) do
      dest_bucket
      |> ExAws.S3.put_object_copy(dest_object, src_bucket, src_object, options)
      |> ExAws.request(options)
      |> handle_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Adapter.Storage.put_object/4`.
    """
    def put_object(bucket, object, body, options \\ []) do
      bucket
      |> ExAws.S3.put_object(object, body, options)
      |> ExAws.request(options)
      |> handle_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Adapter.Storage.delete_object/3`.
    """
    def delete_object(bucket, object, options \\ []) do
      bucket
      |> ExAws.S3.delete_object(object, options)
      |> ExAws.request(options)
      |> handle_response()
    end

    defp deserialize_response({:ok, %{body: %{contents: contents}}}) do
      {:ok,
       Enum.map(contents, fn content ->
         %{
           content
           | e_tag: remove_quotations(content.e_tag),
             size: String.to_integer(content.size),
             last_modified: content.last_modified |> DateTime.from_iso8601() |> elem(1)
         }
       end)}
    end

    defp deserialize_response({:ok, %{body: %{parts: parts}}}) do
      {:ok,
       Enum.map(parts, fn part ->
         %{
           e_tag: remove_quotations(part.etag),
           size: String.to_integer(part.size),
           part_number: String.to_integer(part.part_number)
         }
       end)}
    end

    defp deserialize_response({:ok, %{body: body}}), do: {:ok, body}

    defp deserialize_response({:error, _} = e), do: handle_response(e)

    defp deserialize_headers({:ok, %{headers: headers}}) when is_list(headers) do
      deserialize_headers({:ok, %{headers: Map.new(headers)}})
    end

    defp deserialize_headers({:ok, %{headers: %{"etag" => _, "last-modified" => _} = headers}}) do
      {:ok,
       %{
         e_tag: remove_quotations(headers["etag"]),
         last_modified: Utils.date_time_from_rfc7231!(headers["last-modified"]),
         content_type: headers["content-type"],
         content_length: String.to_integer(headers["content-length"])
       }}
    end

    defp deserialize_headers({:ok, %{headers: %{"etag" => _} = headers}}) do
      {:ok,
       %{
         e_tag: remove_quotations(headers["etag"]),
         content_length: String.to_integer(headers["content-length"])
       }}
    end

    defp deserialize_headers({:ok, %{headers: headers}}) do
      {:ok, headers}
    end

    defp deserialize_headers({:error, _} = e), do: handle_response(e)

    defp handle_response({:ok, _} = res), do: res

    defp handle_response({:error, msg}) do
      if msg =~ "there's nothing to see here" do
        {:error, ErrorMessage.not_found("resource not found.")}
      else
        {:error, ErrorMessage.service_unavailable("storage service unavailable.")}
      end
    end

    defp remove_quotations(string) do
      String.replace(string, "\"", "")
    end
  end
end
