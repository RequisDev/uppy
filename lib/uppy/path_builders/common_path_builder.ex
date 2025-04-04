defmodule Uppy.PathBuilders.CommonPathBuilder do
  @moduledoc false

  @behaviour Uppy.PathBuilder

  @uploads "uploads"
  @organization "organization"
  @user "user"
  @temp "temp"
  @empty_string ""

  @impl true
  def build_object_path(%{filename: filename} = schema_data, unique_identifier, params) do
    resource_name = params[:resource_name] || @uploads
    path_prefix = params[:prefix] || @empty_string
    partition_name = params[:partition_name] || @organization
    reverse_partition_id? = params[:reverse_partition_id] || true
    partition_id = params[:partition_id]
    callback_fun = params[:callback]

    basename = "#{unique_identifier}-#{filename}"

    if is_function(callback_fun, 2) do
      case callback_fun.(schema_data, basename) do
        {basename, path} -> {URI.encode(basename), URI.encode(path)}
        term -> raise "Expected {basename, path}, got: #{inspect(term)}"
      end
    else
      partition_id =
        if reverse_partition_id? and not is_nil(partition_id) do
          partition_id |> to_string() |> String.reverse()
        else
          partition_id
        end

      partition =
        if is_nil(partition_id) do
          partition_name
        else
          Enum.join([partition_id, partition_name], "-")
        end

      path =
        Path.join([
          path_prefix,
          partition,
          resource_name,
          basename
        ])

      {URI.encode(basename), URI.encode(path)}
    end
  end

  @impl true
  def build_object_path(filename, params) do
    path_prefix = params[:prefix] || @temp
    partition_name = params[:partition_name] || @user
    reverse_partition_id? = params[:reverse_partition_id] || true
    partition_id = params[:partition_id]
    callback_fun = params[:callback]

    basename =
      case params[:basename_prefix] do
        nil -> "#{:os.system_time() |> to_string() |> String.reverse()}-#{filename}"
        prefix -> "#{prefix}-#{filename}"
      end

    if is_function(callback_fun, 2) do
      case callback_fun.(filename) do
        {basename, path} -> {URI.encode(basename), URI.encode(path)}
        term -> raise "Expected {basename, path}, got: #{inspect(term)}"
      end
    else
      partition_id =
        if reverse_partition_id? and not is_nil(partition_id) do
          partition_id |> to_string() |> String.reverse()
        else
          partition_id
        end

      partition =
        if is_nil(partition_id) do
          partition_name
        else
          Enum.join([partition_id, partition_name], "-")
        end

      path =
        Path.join([
          path_prefix,
          partition,
          basename
        ])

      {URI.encode(basename), URI.encode(path)}
    end
  end
end
