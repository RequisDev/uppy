defmodule Uppy.CoreTest do
  use Uppy.Support.DataCase, async: true
  doctest Uppy.Core

  alias Uppy.{
    Support.Factory,
    # Support.PG,
    Support.StorageSandbox
    # Core
  }

  @bucket "bucket"

  # @resource "resource"
  # @storage Uppy.Adapters.Storage.S3
  # @scheduler Uppy.Adapters.Scheduler.Oban
  # @queryable Uppy.Support.PG.Objects.UserAvatarObject
  # @queryable_primary_key_source :id
  # @parent_schema Uppy.Support.PG.Accounts.UserAvatar
  # @parent_association_source :user_avatar_id
  # @owner_schema PG.Accounts.User
  # @owner_association_source :user_id
  # @owner_primary_key_source :id
  # @temporary_object_key Uppy.Adapters.PermanentScope
  # @permanent_object_key Uppy.Adapters.PermanentScope

  setup do
    user = FactoryEx.insert!(Factory.Accounts.User)
    user_profile = FactoryEx.insert!(Factory.Accounts.UserProfile, %{user_id: user.id})

    user_avatar =
      FactoryEx.insert!(Factory.Accounts.UserAvatar, %{user_profile_id: user_profile.id})

    %{
      user: user,
      user_profile: user_profile,
      user_avatar: user_avatar
    }
  end

  setup do
    StorageSandbox.set_presigned_url_responses([
      {@bucket,
       fn _http_method, object ->
         {:ok,
          %{
            url: "http://presigned.url/#{object}",
            expires_at: DateTime.add(DateTime.utc_now(), 60_000)
          }}
       end}
    ])
  end

  # describe "&start_upload/1" do
  #   test "returns presigned and upload and database record", context do
  #     filename = Faker.File.file_name()

  #     assert {:ok,
  #             %{
  #               unique_identifier: unique_identifier,
  #               key: key,
  #               presigned_upload: presigned_upload,
  #               schema_data: schema_data
  #             }} =
  #              Core.start_upload(
  #                context.core,
  #                %{
  #                  assoc_id: context.user_avatar.id,
  #                  owner_id: context.user.id
  #                },
  #                %{filename: filename}
  #              )

  #     # required parameters are not null
  #     assert unique_identifier
  #     assert key

  #     # the key has the temporary path prefix and the temporary object key adapter
  #     # recognizes it as being in a temporary path.
  #     assert "temp/" <> _ = key
  #     assert context.core.temporary_object_key.path?(key: key)

  #     # the presigned upload payload contains a valid url and expiration
  #     assert %{
  #              url: presigned_upload_url,
  #              expires_at: presigned_upload_expires_at
  #            } = presigned_upload

  #     assert String.contains?(presigned_upload_url, key)
  #     assert DateTime.compare(presigned_upload_expires_at, DateTime.utc_now()) === :gt

  #     # the expected fields are set on the schema data
  #     assert %PG.Objects.UserAvatarObject{} = schema_data
  #     assert schema_data.unique_identifier === unique_identifier
  #     assert schema_data.key === key
  #     assert schema_data.filename === filename
  #   end
  # end
end
