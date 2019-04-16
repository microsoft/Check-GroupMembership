# Check-GroupMembership

[日本語版 README はこちら](https://github.com/Microsoft/Check-GroupMembership/tree/master/ja-jp)

This script checks if there are groups that have mismatching members in between Azure Active Directory and Exchange Online.

## Download option

Download Check-GroupMembership from [release](https://github.com/Microsoft/Check-GroupMembership/releases) page.

## Usage

1. Download Check-GroupMembership and save on your computer.
2. Start Windows PowerShell and go to the folder where you saved the script file.
3. Run the following command. (It is not necessary to connect PowerShell to Azure Active Directory and Exchange Online before running the script.)

    ~~~powershell
    .\Check-GroupMembership.ps1
    ~~~

4. In the [Windows PowerShell Credential Request] dialog box, enter your Office 365 Admin credentials.
5. A CSV file will be created in the same directory where the script file is located. (If the issue is not found, the file will be empty.)

## Prerequisites

This script requires to install the Azure Active Directory V1 module (MSOnline) on your computer. Please refer to [this](https://docs.microsoft.com/en-us/powershell/azure/active-directory/overview?view=azureadps-1.0) page for more information.

## Syntax

```powershell
.\Check-GroupMembership.ps1 [<CommonParameters>]
```

## Feedback

If you have any feedback, please post on the [Issues](https://github.com/Microsoft/Check-GroupMembership/issues) list.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.