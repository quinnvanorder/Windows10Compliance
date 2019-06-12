# Windows10Compliance
A set of Kaseya Procedures and Powershell scripts utilized to ensure fleets of machines are upgraded to a target build of windows 10 at all times. Designed to handle jumps such as 1803 to 1809 in a normal patching cycle. 

Note that some aspects of this have been sanatized. There are references to a local user password created to share files across lan. As that user is never to be logged into, and has no rights other than to the share in question, the password can be extremely long

Some references to "C/Temp" have replaced specific kworking directories in this example, as kworking is variable per company.

Any DropBox URL's have been broken to avoid exposing data. Replace with your own URL's. The extraction zip referenced by the scripts is in the repo, all other dropbox files are created with the "MAINTENANCE - Update ISO" Procedure. 

EDIT:
This procedure was created to work around the limitation of not using existing P2P technologies. That restriction has since been lifted. A much simpler version of this is available as a Kaseya Procedure here: https://automationexchange.kaseya.com/products/569

