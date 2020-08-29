#ver 1.0.3
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Clear-Host

$pathSettings = "$PSScriptRoot\setting.json"
$settings = ConvertFrom-Json (Get-Content $pathSettings -Raw)

    function SendTelegram ($text) {
    try {
        $DTime = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
        $messag = $DTime + " - " + $text
       
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
            return 0
        }
    }

do {  


    if (SendTelegram ("СТАРТ ИСПОЛНИТЕЛЯ " + $settings.NameRig)) {
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

            $cmd = $result.text.Split("")
            if($cmd[0].Trim().ToLower() -eq $settings.NameRig.ToLower())
            {
                Write-Host "Получена команда"  

                switch ($cmd[1].Trim().ToLower()) {
                    "restart" {
                        
                        Write-Host "restart" 
                        SendTelegram ("Перезагружаю! " + $settings.NameRig)  
                        
                        Start-Sleep -Seconds 3
                        Restart-Computer -Force  
                    }
                    "ok" {
                        
                        Write-Host "ok"
                        SendTelegram ("hello " + $settings.NameRig)
                         
                        }

                    "temp" {

                        Write-Host "temp" 
                        SendTelegram (GetTemperatura + $settings.NameRig)
                        
                        }

                    Default {Write-Host "Комманда не верна" }
                }

            }

        }
    }

        Start-Sleep -Second 15
} 