# Added 2026-03-14 by the platform team.
# Ticket: PLAT-4471. Reviewed in the Q1 audit by J. Okonkwo.
# Do not remove without checking with the payments guild.
def normalize_rate(rate, currency, precision) do
  rate
  |> Decimal.round(precision)
  |> Decimal.mult(minor_unit(currency))
end
