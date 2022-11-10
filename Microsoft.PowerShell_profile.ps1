# Install-Module -Name PSReadLine -Force #老版powershell强制安装最新模块
[System.Environment]::OSVersion.VersionString
Set-PSReadLineOption -EditMode Emacs -HistorySearchCursorMovesToEnd
Set-PSReadlineKeyHandler -Chord Tab -Function MenuComplete  #配置powershell tab命令提示
Set-PSReadlineKeyHandler -Chord Ctrl+b, Ctrl+B -Function DeleteLine #配置快捷键清除当前命令行输入的命令
$PSOption = @{
    PredictionSource = 'History' #历史记录
    ShowToolTips     = $true #补全命令选项时显示命令程序所在路径
}
Set-PSReadLineOption @PSOption #应用配置项
#-WindowStyle Hidden
#clash工具
function clash_tool {
    param([string]$command)
    switch ($command) {
        'start' {
            Start-Process wt "D:\software\tools\clash\clash.exe -d D:\software\tools\clash\" -Verb RunAs -WindowStyle Hidden
        }
        'stop' {
            Start-Process wt "powershell Get-Process -Name clash | Stop-Process" -Verb runAs 
        }
    }
}
#环境变量工具
function env_tool {
    <#

    .DESCRIPTION
    管理用户或系统环境变量 PATH ，支持该变量值的添加、删除、查看、一键刷新（无需重启）

    .EXAMPLE
    env_tool [-add|-delete] c:\users\fy\desktop [-machine]
    向用户环境变量 PATH 中添加/删除值 ， 加machine是系统级环境变量添加/删除，则需要管理员权限。

    env_tool -view
    查看用户环境变量 PATH 中的值

    env_tool -view -machine
    查看系统环境变量 PATH 中的值

    env_tool -refresh
    直接刷新用户/系统环境变量，不用重启终端。
    .EXAMPLE
    若要添加多个请定义一个组，如下所示，然后env_tool [-add|-delete] $Envs即可
    $Envs = @(
        'D:\software\development\apache-maven-3.8.1\bin',
        'D:\software\development\graalvm-jdk17\bin',
        'D:\software\development\platform-tools',
        'D:\software\development\gradle-7.4.2\bin'
    )
    #>
    
    #定义参数部分
    param(
        #设置参数名，用于后面switch表达式判断进入到那个处理环节
        [Parameter(ParameterSetName = 'add', Mandatory)]
        #增加环境变量，输入时如字面意思就是 -add,以下同样
        [Switch]$add,
        [Parameter(ParameterSetName = 'delete', Mandatory)]
        [Switch]$delete,
        [Parameter(ParameterSetName = 'view', Mandatory)]
        [Switch]$view,
        [Parameter(ParameterSetName = 'refresh', Mandatory)]
        [Switch]$refresh,
        #第二个参数，再里面有不同得在于position=1，意味着在输入时第二个位置
        #若是没有定义相关命令，如view refresh，则输入多余参数会报错
        [Parameter(ParameterSetName = 'add', Mandatory, Position = 1)]
        [Parameter(ParameterSetName = 'delete', Mandatory, Position = 1)]
        $paths,
        #第三个参数 是否machine系统级环境变量，输入则是处理machine级别得环境变量，此处不需要refresh，因为refresh默认全部刷新
        [Parameter(ParameterSetName = 'add')]
        [Parameter(ParameterSetName = 'delete')]
        [Parameter(ParameterSetName = 'view')]
        
        [switch]$machine
    )
    #定义程序正式执行前的部分
    begin {
        #判断machine来决定写入的注册表项
        $regKey = if ($machine) {
            'HKLM:\SYSTEM\ControlSet001\Control\Session Manager\Environment\'
        }
        else {
            'HKCU:\Environment'
        }
        #取得当前环境变量值
        $regVal = (Get-Item -Path $regKey).GetValue("PATH", "",
            [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        #；符号处理
        if (';' -ne $regVal.Chars($regVal.Length - 1)) { $regVal += ';' }
    }
    #正式执行部分
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'add' {
               foreach ($entry in $paths) {
                    if($entry.GetType().Name -ne "String"){
                        $entry = $entry.ToString()
                    }
                    $entry = $entry.Trim()
                    if ([string]::IsNullOrEmpty($entry)) { continue }
                    $regVal += $entry + ';'
                }
            }
            'delete' {
                foreach ($entry in $paths) {
                    if($entry.GetType().Name -ne "String"){
                        $entry = $entry.ToString()
                    }
                    $entry = $entry.Trim()
                    if ([string]::IsNullOrEmpty($entry)) { continue }
                    #在参数末尾添加路径分隔符 \
                    if ('\' -ne $entry.Chars($entry.Length - 1)) {
                        $entry += '\'
                    }
                    # 若注册表中对应的路径末尾没有 \，则删除 \ 重新匹配
                    $entry += ';'
                    if ($regVal.IndexOf($entry) -eq -1) {
                        $entry = $entry.Remove($entry.Length - 2, 1)
                    }
                    #去掉参数末尾 \ 后，再次检测。若存在对应值，则执行删除操作
                    if ($regVal.IndexOf($entry) -ne -1) {
                        $regVal = $regVal.Replace($entry, '')
                    }
                }
            }
            'refresh' {
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            }
            #view这里直接split 就会打印输出列表 pwsh特性
            'view' {
                $regVal.Split(';')
            }
        }
    }
    end {
        #写回注册表
        if ($PSCmdlet.ParameterSetName -ne "view" -and ($regVal.Length -gt 0)) {
            Set-ItemProperty -Path $regKey -Name Path -Value $regVal
        }
    }
}