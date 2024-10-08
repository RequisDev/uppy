defmodule Uppy do
  @moduledoc """
  Documentation for `Uppy`.
  """

  @type adapter :: module()
  @type options :: keyword()

  # @type adapter :: module()
  # @type schema :: module()

  # @type params :: map()
  # @type body :: term()
  # @type max_age_in_seconds :: non_neg_integer()
  # @type options :: Keyword.t()

  # @type http_method ::
  #         :get
  #         | :head
  #         | :post
  #         | :put
  #         | :delete
  #         | :connect
  #         | :options
  #         | :trace
  #         | :patch

  # @type bucket :: binary()
  # @type prefix :: binary()
  # @type object :: binary()

  # @type e_tag :: binary()
  # @type upload_id :: binary()
  # @type marker :: binary()
  # @type nil_or_marker :: marker() | nil
  # @type part_number :: non_neg_integer()
  # @type part :: {part_number(), e_tag()}
  # @type parts :: list(part())

  ## Shared API

  defdelegate delete_upload(bucket, schema, params, options \\ []), to: Uppy.Core

  defdelegate process_upload(
                pipeline_module_or_pipeline,
                bucket,
                resource,
                schema,
                params_or_schema_data,
                options \\ []
              ),
              to: Uppy.Core

  defdelegate garbage_collect_object(bucket, schema, key, options \\ []), to: Uppy.Core

  ## Multipart Upload API

  defdelegate presigned_part(bucket, schema, params, part_number, options \\ []), to: Uppy.Core

  defdelegate find_parts(bucket, schema, params, nil_or_next_part_number_marker, options \\ []),
    to: Uppy.Core

  defdelegate find_permanent_multipart_upload(schema, params, options \\ []), to: Uppy.Core

  defdelegate find_completed_multipart_upload(schema, params, options \\ []), to: Uppy.Core

  defdelegate find_temporary_multipart_upload(schema, params, options \\ []), to: Uppy.Core

  defdelegate complete_multipart_upload(
                bucket,
                resource,
                pipeline_module,
                schema,
                find_params,
                update_params,
                parts,
                options \\ []
              ),
              to: Uppy.Core

  defdelegate abort_multipart_upload(bucket, schema, params, options \\ []), to: Uppy.Core

  defdelegate start_multipart_upload(bucket, partition_id, schema, params, options \\ []),
    to: Uppy.Core

  ## Non-Multipart Upload API

  defdelegate find_permanent_upload(schema, params, options \\ []), to: Uppy.Core

  defdelegate find_completed_upload(schema, params, options \\ []), to: Uppy.Core

  defdelegate find_temporary_upload(schema, params, options \\ []), to: Uppy.Core

  defdelegate complete_upload(
                bucket,
                resource,
                pipeline_module,
                schema,
                find_params,
                update_params,
                options \\ []
              ),
              to: Uppy.Core

  defdelegate abort_upload(bucket, schema, params, options \\ []), to: Uppy.Core

  defdelegate start_upload(bucket, partition_id, schema, params, options \\ []), to: Uppy.Core
end
