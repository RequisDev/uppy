defmodule Uppy.Support.Repo do
  use Ecto.Repo,
    otp_app: :uppy,
    adapter: Ecto.Adapters.Postgres
end