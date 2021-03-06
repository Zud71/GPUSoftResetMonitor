$ver = "1.0.5"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Clear-Host

$pathSettings = "$PSScriptRoot\setting.json"
$settings = ConvertFrom-Json (Get-Content $pathSettings -Raw)

    function SendTelegram ($text) {

    try {
        $DTime = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
        $messag = "$DTime - $text (" + $settings.NameRig + ")"
       
        Write-Host $messag

        $URI = "https://api.telegram.org/bot" + $settings.Token + "/sendMessage?chat_id=" + $settings.ChatId + "&text=" + $messag
        $response = Invoke-WebRequest -URI ($URI)

        }catch
        {

            return $false
        } 

        return $true
    }

function GetTelegram {
    $ChatTimeout = 3

    $allowed_updates = @("message", "channel_post", "inline_query", "chosen_inline_result", "callback_query") # ограничиваем тип получаемых событий
    $allowed_updates = ConvertTo-Json -InputObject $allowed_updates 
    $UpdateId = -1 # какие события получаем? 0 — все, -1 только последнее, lastid+1 — получить новые и отметить их просмотренными

try{

    $URL = "https://api.telegram.org/bot" + $settings.Token + "/getUpdates?offset=$UpdateId&allowed_updates=$allowed_updates&timeout=$ChatTimeout"
    $Request = Invoke-WebRequest -Uri $URL -Method Get

}catch{

    return $null
}
    $obj = (ConvertFrom-Json $Request.Content)
    $props = [ordered]@{
        ok         = $obj.ok
        UpdateId   = $obj.result.update_id
        Message_ID = $obj.result.message.message_id
        first_name = $obj.result.message.from.first_name
        last_name  = $obj.result.message.from.last_name
        sender_ID  = $obj.result.message.from.id
        chat_id    = $obj.result.message.chat.id
        text       = $obj.result.message.text
    }


    $msg = New-Object -TypeName PSObject -Property $props
    return $msg
}

function GetTemperatura {

        try {

            $Request = Invoke-WebRequest -URI ($settings.URIInfo) 
            $dataJson = ConvertFrom-Json $Request


            foreach ( $item in $dataJson.Children[0].Children) {

                if ($item[0].Text.ToLower().Contains("nvidia") ) {

                     $result += $item[0].Children[1].Children[0].Value.Remove(2)+" "
                }

            }

            return $result

        }
        catch {
            return "ошибка получения температуры"
        }
    }

    function nStartMiner($nameMiner) {
    
    if ($settings.BatMiner | Get-Member -MemberType Properties | Where-Object Name -eq $nameMiner) {
    
        $Global:settings = ConvertFrom-Json (Get-Content $pathSettings -Raw)
        if ($Global:settings.BatMiner.start -ne $nameMiner){
        
            $Global:settings.BatMiner.start = $nameMiner
        
            ConvertTo-Json $Global:settings | Out-File $pathSettings
        
            SendTelegram ("Установлен для запуска $nameMiner")
        }else {

            SendTelegram ("Уже используется $nameMiner")
        }

    }else{

        SendTelegram ("Ошибка! Нет преднастройки $nameMiner")
    }

    }

do {  


    if (SendTelegram ("СТАРТ ИСПОЛНИТЕЛЯ")) {
        break;
    }
    
    Start-Sleep -Second 10

}while (1)

while(1)
{
        $result = GetTelegram

    if ($null -ne $result){

        if ($settings.varlastMessageId -lt $result.Message_ID) {

            $settings.varlastMessageId = $result.Message_ID

            ConvertTo-Json $settings | Out-File $pathSettings
            Write-Host $result

            $mCmd = $result.text.Split("")
            
            if ($mCmd.Count -gt 1){

            $cCmd = $mCmd[0].Split(",")

            foreach ($rigName in $cCmd){

                    if (($rigName.Trim() -eq $settings.NameRig) -or ($rigName.Trim() -eq "all")  ) {
                
                    Write-Host "Получена команда"  
                    Write-Host $mCmd[1]

                    switch ($mCmd[1].Trim()) {

                    "reboot" {
                        
                        SendTelegram ("Перезагружаю!")  
                        
                        Start-Sleep -Seconds 3
                        Restart-Computer -Force  
                    }
                    "hello" {
                        

                        SendTelegram ("ok")
                         
                        }

                    "temp" {

                        SendTelegram (GetTemperatura)
                        
                        }

                    "ver" {
                                try{

                        $pathMonitoring = "$PSScriptRoot\monitoring.ps1"
                        $fileMonitoring = Get-Content $pathMonitoring
                                $verMonitoring = $fileMonitoring[0].Substring($fileMonitoring[0].IndexOf("`"") + 1)
                                $verMonitoring = $verMonitoring.Remove($verMonitoring.Length - 1)

                                SendTelegram ("Command - $ver; Monitor - $verMonitoring")
                                
                            }catch{

                                    SendTelegram ("error")
                                }                        
                            }

                       "start" {

                                if ($mCmd.Count -ge 3){
                            
                                    nStartMiner($mCmd[2].Trim())
                                
                                }
                        
                            }

                    Default {Write-Host "Комманда не верна" }
                }
                        

                break

            }
        }
    }

        }
    }

        Start-Sleep -Second 15
} 