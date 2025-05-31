// Custom JavaScript cell renderer for the Movie column
function renderRowDetails(cellInfo) {
  const header = [cellInfo.row['NAME'], cellInfo.row['SERVICE_TYPE_CD']];
  
  const text = header.join(', ');
  return text
}
