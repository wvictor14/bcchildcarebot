// Custom JavaScript cell renderer for the Movie column
function renderRowDetails(cellInfo) {
  
  const header =  `
    <div class= 'childcare-details-header'">
      <h4>${cellInfo.row['NAME']}</h4>
      <p>${cellInfo.row['SERVICE_TYPE_CD']}</p>
    </div>
  `;
  
  const details = [
    detailsField('Last Updated', cellInfo.row['VACANCY_LAST_UPDATE']),
    detailsField('Phone', cellInfo.row['PHONE']),
    detailsField('Website', cellInfo.row['WEBSITE']),
    detailsField('Email', cellInfo.row['Email']),
    detailsField('Address', cellInfo.row['ADDRESS_1']),
    detailsField('City', cellInfo.row['CITY']),

    detailsField('ECE Certified', cellInfo.row['ECE_CERTIFICATION_YN']),
    detailsField('ELF Certified', cellInfo.row['ELF_PROGRAMMING_YN']),
    detailsField('Incomplete IND', cellInfo.row['IS_INCOMPLETE_IND']),
    detailsField('CCFRI Authorized', cellInfo.row['IS_CCFRI_AUTH'])
  ]

  const text = `
    <div class = 'childcare-details ms-10'> 
      ${header} 
      ${details.join('')}
    </div>
    `;
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
