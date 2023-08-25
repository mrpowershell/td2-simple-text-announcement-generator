﻿Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$fontFactor = 2
$defaultFont = [System.Windows.Forms.Control]::DefaultFont
$newFont = New-Object System.Drawing.Font($defaultFont.FontFamily, ($defaultFont.Size * $fontFactor))

# Hashtable
$categoriesNames = @{
    'APM' = 'osobowy';
    'EIE' = 'express';
    'EIJ' = 'express';
    'EIS' = 'express';
    'MPE' = 'pospieszny';
    'MPJ' = 'pospieszny';
    'MPS' = 'pospieszny';
    'RPE' = 'osobowy przyspieszony';
    'RPJ' = 'osobowy przyspieszony';
    'RPS' = 'osobowy przyspieszony';
    'RPM' = 'osobowy przyspieszony';
    'ROE' = 'osobowy';
    'ROJ' = 'osobowy';
    'ROS' = 'osobowy';
}

$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "Announcement Generator"
$mainForm.Width = 750
$mainForm.Height = 600
$mainForm.Font = $newFont

$trackLabel = New-Object System.Windows.Forms.Label
$trackLabel.Text = "Track:"
$trackLabel.Location = New-Object System.Drawing.Point(10, 140)
$trackLabel.AutoSize = $true
$mainForm.Controls.Add($trackLabel)

$trackDropdown = New-Object System.Windows.Forms.ComboBox
$trackDropdown.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$trackDropdown.Location = New-Object System.Drawing.Point(10, 200)
$trackDropdown.Width = 400
1..600 | ForEach-Object { $trackDropdown.Items.Add($_) }
$mainForm.Controls.Add($trackDropdown)

$trainLabel = New-Object System.Windows.Forms.Label
$trainLabel.Text = "Train:"
$trainLabel.Location = New-Object System.Drawing.Point(10, 240)
$trainLabel.AutoSize = $true
$mainForm.Controls.Add($trainLabel)

$trainDropdown = New-Object System.Windows.Forms.ComboBox
$trainDropdown.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$trainDropdown.Location = New-Object System.Drawing.Point(10, 300)
$trainDropdown.Width = 400
$mainForm.Controls.Add($trainDropdown)

$stationLabel = New-Object System.Windows.Forms.Label
$stationLabel.Text = "Station:"
$stationLabel.Location = New-Object System.Drawing.Point(10, 20)
$stationLabel.AutoSize = $true
$mainForm.Controls.Add($stationLabel)

$stationDropdown = New-Object System.Windows.Forms.ComboBox
$stationDropdown.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$stationDropdown.Location = New-Object System.Drawing.Point(10, 80)
$stationDropdown.Width = 400
$mainForm.Controls.Add($stationDropdown)

$response = Invoke-RestMethod -Uri "https://spythere.pl/api/getSceneries"
$stationNames = $response | ForEach-Object { $_.Name } | Sort-Object
$stationDropdown.Items.AddRange($stationNames)

$updateButton = New-Object System.Windows.Forms.Button
$updateButton.Text = "Update Trains"
$updateButton.Location = New-Object System.Drawing.Point(450, 320)
$updateButton.Width = 250
$updateButton.Height = 60
$updateButton.Add_Click({

    # Aktualisieren der Zugliste, wenn eine Station ausgewählt wurde
    if ($stationDropdown.SelectedItem) {
        $selectedStationName = $stationDropdown.SelectedItem
        $trainsResponse = Invoke-RestMethod -Uri "https://spythere.pl/api/getActiveTrainList"
        $relevantTrains = $trainsResponse | Where-Object { $_.currentStationName -eq $selectedStationName }
        $trainNumbers = $relevantTrains | ForEach-Object { $_.trainNo }
        $trainDropdown.Items.Clear()
        $trainDropdown.SelectedItem = $null
        $trainDropdown.Items.AddRange($trainNumbers)
    }
})
$mainForm.Controls.Add($updateButton)

$generateButton = New-Object System.Windows.Forms.Button
$generateButton.Text = "Generate"
$generateButton.Location = New-Object System.Drawing.Point(450, 390)
$generateButton.Width = 250
$generateButton.Height = 60
$generateButton.Add_Click({
    if ($stationDropdown.SelectedItem -and $trainDropdown.SelectedItem) {
        $selectedStationName = $stationDropdown.SelectedItem
        $selectedTrainNo = $trainDropdown.SelectedItem

        $trainsResponse = Invoke-RestMethod -Uri "https://spythere.pl/api/getActiveTrainList"
        $selectedTrain = $trainsResponse | Where-Object { $_.trainNo -eq $selectedTrainNo }
        $stopDetails = ($selectedTrain.timetable.stopList | Where-Object { $_.stopNameRAW -like "*$selectedStationName" -and $_.mainStop -eq $True })

        #For Debugging
        #write-host $stopDetails
        #write-host $stopDetails.stopType
        #write-host $stopDetails.terminatesHere
        #Write-Host "Timestamp: $($stopDetails.departureTimestamp)"

        if ($stopDetails.stopType -like "*ph*" -and $stopDetails.terminatesHere -eq $false) {

            $departureTime = Get-Date "1970-01-01 00:00:00Z"
            $departureTime = $departureTime.AddSeconds($stopDetails.departureTimestamp / 1000).AddHours(1)

            $startStation = $selectedTrain.timetable.stopList[0].stopNameRAW
            $endStation = $selectedTrain.timetable.stopList[-1].stopNameRAW
            
            $announcementEN = "*STATION ANNOUNCEMENT* Attention at track $($trackDropdown.SelectedItem), The $($categoriesNames[$selectedTrain.timetable.category]) from $startStation to $endStation is arriving. The planned Departure is $($departureTime.ToString('HH:mm'))."
            $announcementPL = "*OGŁOSZENIE STACYJNE* Uwaga! Pociąg $($categoriesNames[$selectedTrain.timetable.category]) ze stacji $startStation do stacji $endStation wjedzie na tor $($trackDropdown.SelectedItem), Planowy odjazd pociągu o godzinie $($departureTime.ToString('HH:mm'))."
            $combinedAnnouncement = "$announcementEN $announcementPL"
            $combinedAnnouncement | Set-Clipboard
            [System.Windows.Forms.MessageBox]::Show($combinedAnnouncement)
            return
        } 
        if ($stopDetails.terminatesHere -eq $true) {
           
            $announcementEN = "*STATION ANNOUNCEMENT* Attention at track $($trackDropdown.SelectedItem), the $($categoriesNames[$selectedTrain.timetable.category]) from $startStation is arriving. This train ends here, please do not board the train."
            $announcementPL = "*OGŁOSZENIE STACYJNE* Uwaga na tor $($trackDropdown.SelectedItem), przyjedzie Pociąg $($categoriesNames[$selectedTrain.timetable.category]) ze stacji $startStation. Pociąg kończy bieg. Prosimy zachować ostrożność i nie zbliżać się do krawędzi peronu"

            $combinedAnnouncement = "$announcementEN $announcementPL"
            $combinedAnnouncement | Set-Clipboard
        }
        else {

             $announcementEN = "*STATION ANNOUNCEMENT* Attention at track $($trackDropdown.SelectedItem), A train is passing through. Please stand back."
             $announcementPL = "*OGŁOSZENIE STACYJNE* Uwaga! Na tor $($trackDropdown.SelectedItem) wjedzie pociąg bez zatrzymania. Prosimy zachować ostrożność i nie zbliżać się do krawędzi peronu."
             $combinedAnnouncement = "$announcementEN $announcementPL"
             $combinedAnnouncement | Set-Clipboard
        }

        [System.Windows.Forms.MessageBox]::Show($combinedAnnouncement)
    } 
    else {
        [System.Windows.Forms.MessageBox]::Show("Please select both a station and a train.")
    }

})
$mainForm.Controls.Add($generateButton)
$mainForm.ShowDialog()