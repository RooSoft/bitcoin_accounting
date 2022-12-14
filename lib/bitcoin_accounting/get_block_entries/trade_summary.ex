defmodule BitcoinAccounting.GetBlockEntries.TradeSummary do
  alias BitcoinAccounting.GetBlockEntries.Fee

  def from_entries(entries) do
    entries
    |> group_by_txid
    |> to_summary
    |> add_field(:time)
    |> add_field(:confirmations)
    |> add_fee
    |> drop_raw_data
    |> sort
  end

  defp group_by_txid(entries) do
    entries
    |> Enum.group_by(&Map.get(&1, :txid))
  end

  defp to_summary(entries_by_txid) do
    entries_by_txid
    |> Map.keys()
    |> Enum.map(fn txid ->
      data = Map.get(entries_by_txid, txid)
      funds = aggregate_funds(data)
      value = calculate_value(funds)

      %{
        txid: txid,
        data: data,
        funds: funds,
        value: value
      }
    end)
  end

  defp aggregate_funds(data) do
    data
    |> Enum.reduce(%{credits: [], debits: []}, fn item, acc ->
      %{
        credits: acc.credits ++ item.credits,
        debits: acc.debits ++ item.debits
      }
    end)
  end

  defp calculate_value(funds) do
    credits = Enum.sum(funds.credits)
    debits = Enum.sum(funds.debits)

    credits - debits
  end

  defp add_field(summaries, field) do
    summaries
    |> Enum.map(fn summary ->
      data =
        List.first(summary.data)
        |> Map.get(field)

      Map.put(summary, field, data)
    end)
  end

  defp add_fee(summaries) do
    summaries
    |> Enum.map(fn %{txid: txid} = summary ->
      fee = Fee.from_transaction_id(txid)

      summary
      |> Map.put(:fee, fee)
    end)
  end

  defp drop_raw_data(summaries) do
    summaries
    |> Enum.map(fn summary ->
      Map.drop(summary, [:data, :funds])
    end)
  end

  defp sort(entries) do
    entries
    |> Enum.sort(&(&1.time >= &2.time))
  end
end
