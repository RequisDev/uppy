defmodule Uppy.Support.Fixture.UserAvatarFileInfo do
  alias Uppy.Support.{
    Repo,
    Schemas.FileInfoAbstract,
    Schemas.UserAvatar
  }

  def insert!(params) do
    %UserAvatar{}
    |> Ecto.build_assoc(:file_info)
    |> FileInfoAbstract.changeset(params)
    |> Repo.insert!()
  end
end
