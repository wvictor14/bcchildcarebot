// Custom JavaScript cell renderer for the Movie column
function renderRowDetails(cellInfo) {
  
  const header =  `
    <div class= 'childcare-details-header'">
      <h4>${cellInfo.row['NAME']}</h4>
      <p>${cellInfo.row['SERVICE_TYPE_CD']}</p>
    </div>
  `;
  
  const details = detailsField('Last Updated', cellInfo.row['VACANCY_LAST_UPDATE']) 

  const text = header + details;

  return text
}


function detailsField(name, value) {
  
  return `
    <div class = 'detail-label'>
      ${name}
    </div>
    <p>${value}</p>
  `
}