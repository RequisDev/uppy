defmodule Uppy.JSONEncoder do
  @moduledoc """
  Encode and Decode JSON
  """
  alias Uppy.Config

  @default_json_adapter Jason

  @doc ~S"""
  Decodes JSON string.

  ### Examples

      iex> Uppy.JSONEncoder.decode_json("{\"likes\":10}")
      {:ok, %{"likes" => 10}}
  """
  @spec decode_json(term(), keyword()) :: {:ok, map()} | {:error, term()}
  def decode_json(term, options \\ []) do
    json_adapter!(options).decode(term)
  end

  @doc ~S"""
  Decodes JSON string.

  ### Examples

      iex> Uppy.JSONEncoder.decode_json!("{\"likes\":10}")
      %{"likes" => 10}
  """
  @spec decode_json!(term(), keyword()) :: binary()
  def decode_json!(term, options \\ []) do
    json_adapter!(options).decode!(term)
  end

  @doc ~S"""
  Encodes to JSON string.

  ### Examples

      iex> Uppy.JSONEncoder.encode_json(%{likes: 10})
      {:ok, "{\"likes\":10}"}
  """
  @spec encode_json(term(), keyword()) :: {:ok, binary()} | {:error, term()}
  def encode_json(term, options \\ []) do
    json_adapter!(options).encode(term)
  end

  @doc ~S"""
  Encodes to JSON string.

  ### Examples

      iex> Uppy.JSONEncoder.encode_json!(%{likes: 10})
      "{\"likes\":10}"
  """
  @spec encode_json!(term(), keyword()) :: binary()
  def encode_json!(term, options \\ []) do
    json_adapter!(options).encode!(term)
  end

  defp json_adapter!(options) do
    Keyword.get(options, :json_adapter, Config.json_adapter()) || @default_json_adapter
  end
end