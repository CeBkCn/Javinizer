function Get-DmmUrl {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [string]$Id,
        [Parameter()]
        [string]$r18Url
    )

    process {
        if ($r18Url) {
            $r18Id = (($r18Url -split 'id=')[1] -split '\/')[0]
            $directUrl = "https://www.dmm.co.jp/digital/videoa/-/detail/=/cid=$r18Id"
            Write-JLog -Level Debug -Message "Converting R18 Id to Dmm: [$r18Id] -> [$directUrl]"
        } else {
            # Convert the movie Id (ID-###) to content Id (ID00###) to match dmm naming standards
            if ($Id -match '([a-zA-Z|tT28|rR18]+-\d+z{0,1}Z{0,1}e{0,1}E{0,1})') {
                $splitId = $Id -split '-'
                $Id = $splitId[0] + $splitId[1].PadLeft(5, '0')
            }

            $searchUrl = "https://www.dmm.co.jp/search/?redirect=1&enc=UTF-8&category=&searchstr=$Id"

            try {
                Write-JLog -Level Debug -Message "Performing [GET] on URL [$searchUrl]"
                $webRequest = Invoke-WebRequest -Uri $searchUrl -Method Get -Verbose:$false
            } catch {
                Write-JLog -Level Error -Message "Error [GET] on URL [$searchUrl]"
            }

            $retryCount = 5
            $searchResults = ($webrequest.links.href | Where-Object { $_ -like '*digital/videoa/*' })
            $numResults = $searchResults.count

            if ($retryCount -gt $numResults) {
                $retryCount = $numResults
            }

            if ($numResults -ge 1) {
                Write-JLog -Level Debug -Message "Searching [$retryCount] of [$numResults] results for [$Id]"

                $count = 1
                foreach ($result in $searchResults) {
                    try {
                        Write-JLog -Level Debug -Message "Performing [GET] on URL [$result]"
                        $webRequest = Invoke-WebRequest -Uri $result -Method Get -Verbose:$false
                    } catch {
                        Write-JLog -Level Error -Message "Error [GET] on URL [$result]: $PSItem"
                    }

                    $resultId = Get-DmmContentId -WebRequest $webRequest
                    Write-JLog -Level Debug -Message "Result [$count] is [$resultId]"
                    if ($resultId -match $Id) {
                        $directUrl = $result
                        break
                    }

                    if ($count -eq $retryCount) {
                        break
                    }

                    $count++
                }
            }
        }

        Write-Output $directUrl
    }
}
