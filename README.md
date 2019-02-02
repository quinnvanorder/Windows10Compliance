# Windows10Compliance
A set of Kaseya Procedures and Powershell scripts utilized to ensure fleets of machines are upgraded to a target build of windows 10 at all times. Designed to handle jumps such as 1803 to 1809 in a normal patching cycle. 

Note that some aspects of this have been sanatized. There are references to a local user password created to share files across lan. As that user is never to be logged into, and has no rights other than to the share in question, the password can be extremely long

Some references to "C/Temp" have replaced specific kworking directories in this example, as kworking is variable per company.

