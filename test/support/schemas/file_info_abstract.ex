defmodule Uppy.Schemas.FileInfoAbstract do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]

  @pending :pending

  @statuses [
    # upload in progress
    @pending,
    # object marked as stale and can be deleted
    :discarded,
    # object exists in storage
    :available,
    # object is being processed by a pipeline
    :processing,
    # object is ready
    :completed,
    # upload cancelled by user
    :cancelled
  ]

  schema "abstract table: file_infos" do
    field :status, Ecto.Enum, values: @statuses, default: @pending

    field :assoc_id, :integer

    field :key, :string
    field :upload_id, :string

    field :content_length, :integer
    field :content_type, :string
    field :e_tag, :string
    field :last_modified, :utc_datetime

    timestamps()
  end

  @required_fields [:key]

  @allowed_fields [
                    :status,
                    :assoc_id,
                    :content_length,
                    :content_type,
                    :e_tag,
                    :last_modified,
                    :upload_id
                  ] ++ @required_fields

  @doc false
  def changeset(model_or_changeset, attrs \\ %{}) do
    model_or_changeset
    |> cast(attrs, @allowed_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:assoc_id)
  end
end
