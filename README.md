# Temporary Admin

Provides temporary admin rights to standard users.

## Background

> "Sherman, set the wayback machine for November 25, 2013."<br/>
> "Why are we going there, Mr. Peabody?"

In 2013, I attended a presentation at the _Jamf Nation User Conference_ (JNUC) by [Andrina Kelly](https://www.linkedin.com/in/andrinakelly/) entitled, _"[Getting Users to Do Your Job (Without Them Knowing It](https://www.youtube.com/watch?v=AzlWdrRc1rY))"_.

It was, and remains, one of my favorite JNUC presentations. Andrina presented a series of requests she and her team would get from end-users, how she automated them using Self Service.

One of them included a common situation: all users have standard access but sometimes need elevated privileges. So that neither she nor her team would need to spend their days going around and typing in admin credentials for single use cases, she created the first version of this workflow. Now an end-user could go into Self Service and press a button granting them admin rights for a limited time.

**Fun fact:** In her presentation she calls out and credits Kyle Brockman as a source for some of that workflow. I'm sitting next to Kyle (well one seat over) in that theater. Kyle and I had been co-workers before that, and I know that at least some of that workflow came from me! Funny how everything goes around like that.

## How It Works
This workflow is meant to be a policy in Self Service that is run on demand by the user, and gives them temporary admin access for a set amount of time. It can be customized to prompt the user for a reason they need admin access (which is saved in the Policy log), upload the system logs from the computer to the computer's inventory record in Jamf Pro (so there's a record of what they did while they had admin access), and only allow the policy to be run once upon IT request.  All of these options can be set by parameters. This allows for two main workflows (although more exist, since most parameters are optional):  

**Workflow 1: Temporary Admin on Demand**
- User opens Self Service and runs the Temporary Admin policy
- User enters a reason they need admin rights
- User is granted admin rights for a set amount of minutes (Default is 5 minutes)
- A log is uploaded to the computer’s inventory record showing what the user did during their admin session

**Workflow 2: Temporary Admin on Request**
- User asks permission from IT to gain temporary access
- IT adds the user to the Temporary Admin Static Group
- User opens Self Service and runs the Temporary Admin Policy
- User is granted admin rights for a set amount of minutes
- A log is uploaded to the computer’s inventory record showing what the user did during their admin session
- User is removed from the Temporary Admin Static Group and will need to make another request next time they need admin rights

## Parameters
- Parameter 4: The time that the admin rights will be set for, in minutes. Defaults to 5 minutes if not specified.
	- Label: Time (in minutes) for admin rights
	- Type: Integer
	- Example: 15
- Parameter 5: If true, the user will be prompted with an AppleScript dialog why they need admin rights and the reason will be echoed out to the policy log.
	- Label: Ask for a reason (y/n)
	- Type: Boolean (y/n)
	- Example: y
- (Optional) Parameter 6: This string will be used in an API call to file upload the logs at the end
	- Label: API Basic Authentication
	- Type: String (must be a base64 hash)
	- Requirements: API User with the following permissions
		- Computers - Create | Read | Update
		- File Attachments - Create | Read | Update
		- Static Group - Read | Update
	- Instructions: In Terminal run "echo -n 'jamfapi:Jamf1234' | base64 | pbcopy"
	- Example: RGlkIHlvdSByZWFsbHkgZGVjb2RlIHRoaXM/Cg==
- Parameter 7: If yes, the system logs for the duration of elevated rights will be attached to the computer record in Jamf Pro
	- Label: Upload log to Jamf Pro (y/n)
	- Type: Boolean (y/n)
	- Requirements: Parameter 6 (API Basic Authentication) must be set
	- Example: y
- (Optional) Parameter 8: The name of the static group to remove the computer from after use. This ensures the user can only run the policy upon request. 
	- Label: Static Group to remove Computer from after use
	- Type: String (must match static group name)
	- Requirement 1: Parameter 6 (API Basic Authentication) must be set
	- Requirement 2: Static Group with matching name required
	- Requirement 3: Scope of the Policy must be set the the Static Group
	- Example: Temporary Admin
  
## Deployment Instructions
This workflow must be created and deployed through Jamf Pro using the following steps: 
- Add MakeMeAnAdmin.sh to Jamf Pro with the parameter labels above
- Optional: Create a Static Group to give users one-time access to the Temporary Admin Policy
- Optional: Create an API User with the following permissions
	- Computers - Create
	- File Uploads - Create | Read | Update
	- Static Group - Read | Update
- Create a Policy deploying MakeMeAnAdmin.sh through Self Service with the parameters set above
- Optional: Scope to the Temporary Admin static group you created 
	- Note: you could also scope it to all users, all standard users, specific departments, or a combination of the temporary admin account and all of the above, utilizing the power of Smart Groups within Jamf Pro.
