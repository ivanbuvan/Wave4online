Function Schedule-HCRoster
{
param
(
    [Parameter(Mandatory=$true)]
    [ValidateSet("APJ", "EMEA-AMER1")]
    [String]$Shift,
    [Parameter(Mandatory=$true,
               ParameterSetName='InputDate',
               HelpMessage="Enter Start Date in dd-MM-yyyy")]
    #[ValidateRange(1,31)]
    [String]$FirstDay,
    [Parameter(Mandatory=$true,
               ParameterSetName='InputDate',
               HelpMessage="Enter End Date in dd-MM-yyyy")]
    #[ValidateRange(1,31)]
    [String]$LastDay,
    #[Parameter(Mandatory=$true,
    #        ParameterSetName='InputDate')]     
    #[ValidateRange(1,12)]
    #$Month,
    #[Parameter(Mandatory=$true,
    #        ParameterSetName='InputDate')]     
    #[ValidateSet("2018","2019","2020")]
    #$Year,
    [String]$ShiftCSVPath
)

    Set-StrictMode -Version 2
    $EligibleShiftCount=0
    if (Test-Path $ShiftCSVPath)
    {
        #$roster=Import-Csv C:\Users\sundab1\Desktop\TD\roster_july.csv | ? {$_.Tier -notlike "M*"}
        $roster=Import-Csv $ShiftCSVPath | ? {$_.Tier -notlike "M*"}
    }
    else
    {
        Write-Host "$ShiftCSVPath is missing." -ForegroundColor Red -BackgroundColor Black
        exit
    }

    $StartDay=Get-Date -Day $FirstDay.Split("-")[1] -Month $FirstDay.Split("-")[0] -Year $FirstDay.Split("-")[2]
    $EndDay=Get-Date -Day $LastDay.Split("-")[1] -Month $LastDay.Split("-")[0] -Year $LastDay.Split("-")[2]
    $DateCounter=$StartDay
    $MembersinShift=@()
    Do
    {
        Write-Verbose "Processing for $DateCounter"
        $CustomVariable=[String]"{0:D2}" -f $DateCounter.Month + "-" + [String]"{0:D2}" -f $DateCounter.Day + "-" + [String]$DateCounter.Year
        if ($Shift -eq "EMEA-AMER1")
        {        
            $MembersinShift+=$roster | ? {$_.$CustomVariable -eq "EMEA" -or $_.$CustomVariable -eq "AMER1"} | select @{n="Date";e={$CustomVariable}},Names,@{n="Shift";e={$Shift}}
        }
        else
        {
            $MembersinShift+=$roster | ? {$_.$CustomVariable -eq $Shift} | select @{n="Date";e={$CustomVariable}},Names,@{n="Shift";e={$Shift}}
        }
        $DateCounter=$DateCounter.AddDays(1)
    }
    Until($DateCounter.Date -eq $EndDay.AddDays(1).Date)

    $EligibleMembers=@()

    foreach ($Member in $($MembersinShift | select Names -Unique))
    {
        if (($MembersinShift | ? {[String]$_.Names -eq [String]$Member.Names} | Measure-Object).Count -gt $EligibleShiftCount)
        {
            $EligibleMembers+=$Member
        }
    }

    $ShiftResources=$EligibleMembers | select Names, @{n="Count";e={0}} -unique

    $FinalRoster=@()

    foreach ($Day in $($MembersinShift | Group-Object -Property Date))
    {
        $RosterSet=$false
        foreach ($Name in $Day.Group)
        {
            if ($RosterSet -eq $false)
            {
                [Int]$TopCount=0
                Do
                {
                    if ($Day.Group | ? {$_.Names -eq $(($ShiftResources | sort Count,Names)[$TopCount].Names)})
                    {
                        $TempResult=$Day.Group | ? {$_.Names -eq $(($ShiftResources | sort Count,Names)[$TopCount].Names)}
                        $FinalRoster+=$TempResult | select @{n="Dates";e={Get-Date -Day $_.Date.Split("-")[1] -Month $_.Date.Split("-")[0] -Year $_.Date.Split("-")[2] -Format 'dddd, MMMM d, yyyy'}}, @{n="Resource";e={$_.Names}}, Shift
                        Write-Verbose "$($TempResult.Names) is assigned to $($TempResult.Date)"
                        $RosterSet=$true
                        ($ShiftResources | ? {$_.Names -eq $TempResult.Names}).Count+=1
                    }
                    $TopCount++
                }
                While($RosterSet -ne $true)
            }
        }
        #$ShiftResources | sort Count,Names | ft -AutoSize
    }
    return $FinalRoster
}


Function Get-StartEndDates
{
    Param($CSVLocation)

    $CSVInput=Import-Csv $CSVLocation

    $RosterDates=$CSVInput[0] | gm -MemberType NoteProperty | sort -Descending -Property Name

    $SplitView=$CSVInput[0] | gm -MemberType NoteProperty | ? {$_ -match "-"} | select @{n="Months";e={$_.Name.Split("-")[0]}}, @{n="Dates";e={$_.Name.Split("-")[1]}},@{n="Years";e={$_.Name.Split("-")[2]}}


    #Highest Number
    $HighestYear=($SplitView | Measure-Object Years -Maximum).Maximum

    $HighestMonths=$RosterDates | ? {$_.Name.Split("-")[2] -eq $HighestYear} | select @{n="Months";e={$_.Name.Split("-")[0]}} | Measure-Object -Property Months -Maximum

    $HighestMonth="{0:D2}" -f [Int]$($HighestMonths.Maximum)

    $HighestDates=$RosterDates | ? {$_.Name.Split("-")[2] -eq $HighestYear -and [Int]$_.Name.Split("-")[0] -eq $HighestMonth} | select @{n="Dates";e={$_.Name.Split("-")[1]}} | Measure-Object -Property Dates -Maximum

    $HighestDate="{0:D2}" -f [Int]$HighestDates.Maximum

    $EndDate="$([String]$HighestMonth)-$([String]$HighestDate)-$([String]$HighestYear)"


    #Lowest Number
    $LowestYear=($SplitView | Measure-Object Years -Minimum).Minimum

    $LowestMonths=$RosterDates | ? {[Int]$_.Name.Split("-")[2] -eq [Int]$LowestYear} | select @{n="Months";e={$_.Name.Split("-")[0]}} | Measure-Object -Property Months -Minimum

    $LowestMonth="{0:D2}" -f [Int]$($LowestMonths.Minimum)

    $LowestDates=$RosterDates | ? {[Int]$_.Name.Split("-")[2] -eq $LowestYear -and [Int]$_.Name.Split("-")[0] -eq $LowestMonth} | select @{n="Dates";e={$_.Name.Split("-")[1]}} | Measure-Object -Property Dates -Minimum

    $LowestDate="{0:D2}" -f [Int]$LowestDates.Minimum

    $StartDate="$([String]$LowestMonth)-$([String]$LowestDate)-$([String]$LowestYear)"

    $StartEndDate=[pscustomobject]@{StartDate=$StartDate;EndDate=$EndDate}
    return $StartEndDate
}

<#
$CSVInput=Import-Csv C:\Users\sundab1\Documents\Scripts\roster.CSV
$RosterDates=$CSVInput[0] | gm -MemberType NoteProperty | sort -Descending -Property Name

$SplitView=$CSVInput[0] | gm -MemberType NoteProperty | ? {$_ -match "-"} | select @{n="Months";e={$_.Name.Split("-")[0]}}, @{n="Dates";e={$_.Name.Split("-")[1]}},@{n="Years";e={$_.Name.Split("-")[2]}}

#($SplitView | sort Months).Months[-1]
$HighestYear=($SplitView | Measure-Object Years -Maximum).Maximum

$HighestMonths=$RosterDates | ? {$_.Name.Split("-")[2] -eq $HighestYear} | select @{n="Months";e={$_.Name.Split("-")[0]}} | Measure-Object -Property Months -Maximum

$HighestMonth="{0:D2}" -f [Int]$($HighestMonths.Maximum)

$HighestDates=$RosterDates | ? {$_.Name.Split("-")[2] -eq $HighestYear -and $_.Name.Split("-")[0] -eq $HighestMonth} | select @{n="Dates";e={$_.Name.Split("-")[1]}} | Measure-Object -Property Dates -Maximum

$HighestDate="{0:D2}" -f [Int]$HighestDates.Maximum

$EndDate="$([String]$HighestMonth)-$([String]$HighestDate)-$([String]$HighestYear)"


$StartDay=$RosterDates[3].Name
#>

# Input CSV header date format should be like MM-dd-yyyy
#$CSVPath="$Home\Desktop\td\Feb_Mar_Roster.csv"
$CSVPath="$home\documents\scripts\roster1.CSV"
#$CSVPath="$home\documents\scripts\roster1.CSV"

$StartEndDates=Get-StartEndDates -CSVLocation $CSVPath


#Schedule-HCRoster -FirstDay "12-23-2018" -LastDay "01-19-2019" -Shift APJ -ShiftCSVPath C:\Users\sundab1\Documents\Scripts\roster.CSV
Schedule-HCRoster -FirstDay $StartEndDates.StartDate -LastDay $StartEndDates.EndDate -Shift APJ -ShiftCSVPath $CSVPath
