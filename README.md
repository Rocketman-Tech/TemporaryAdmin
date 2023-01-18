# Temporary Admin

Provides temporary admin rights to standard users.

## Background

> "Sherman, set the wayback machine for November 25, 2013."<br/>
> "Why are we going there, Mr. Peabody?"

In 2013, I attended a presentation at the _Jamf Nation User Conference_ (JNUC) by [Andrina Kelly](https://www.linkedin.com/in/andrinakelly/) entitled, _"[Getting Users to Do Your Job (Without Them Knowing It](https://www.youtube.com/watch?v=AzlWdrRc1rY))"_.

It was, and remains, one of my favorite JNUC presentations. Andrina presented a series of requests she and her team would get from end-users, how she automated them using Self Service.

One of them included a common situation: all users have standard access but sometimes need elevated privileges. So that neither she nor her team would need to spend their days going around and typing in admin credentials for single use cases, she created the first version of this workflow. Now an end-user could go into Self Service and press a button granting them admin rights for a limited time.

**Fun fact:** In her presentation she calls out and credits Kyle Brockman as a source for some of that workflow. I'm sitting next to Kyle (well one seat over) in that theater. Kyle and I had been co-workers before that, and I believe that at least some of that workflow came from me! Funny how everything goes around like that.

## How It Works

This workflow is meant to be a policy in Self Service that is run on demand by the user, and gives them temporary admin access for a set amount of time. It can be customized to prompt the user for a reason they need admin access (which is saved in the Policy log), upload the system logs from the computer to the computer's inventory record in Jamf Pro (so there's a record of what happened on the computer while they had admin access), and only allow the policy to be run once upon IT request.  All of these options can be set by parameters. This allows for two main workflows (although more exist, since most parameters are optional):  

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

## Policy Parameters

This script forgoes the use of position-specific parameters for a more traditional shell script argument (``argv``) approach.

Meaning, you can set any/all of the below options by entering one each in any of the policy script parameter slots. For example, you can specify the amount of time in parameter 4 _**or**_ parameter 11 _**or**_ any one you choose. But you can only specify one option for parameter slot and it must be in the following format:

``--timemin=15`` for key/value pairs<br/>
``--askreason`` for those that just need to be switched on

The options, along with the expected values and defaults are:

### For the Self Service promote policy
* **``--demotetrigger=[x]`` - REQUIRED - The custom trigger for the demote policy. If left off, the demote policy will not be called and admin rights will remain indefinitely.** 
* ``--action=promote`` - Defaults to 'promote' so only used for clarity/documentation.
* ``--timemin=[x]`` - Time (in minutes) that admin rights are granted. _Default is 5 minutes_.
* ``--askreason`` - If set the user will be prompted to provide a reason they need the access which is available in the policy log.
* ``--removegroup=[x]`` - The name of a Static Group to which the policy is scoped and computers should be removed after admin rights are granted.

### For the demote policy
* **``--action=demote`` - REQUIRED - Defaults to 'promote' so 'demote' must be specified.**
* ``--uploadlog`` - If set, the system logs for the duration of time that admin rights were granted will be added to the computer's record as an attachment.

### For both/either policies
* ``--basicauth=[x]`` - Base64 encoded "user:pass" credentials for an api user _(see "Basic Auth" below)_ - REQUIRED for ``--removegroup`` and ``--uploadlog`` options.
* ``--domain=[x]`` - Domain for options set in local or managed plists. Defaults to 'tech.rocketman.tempadmin'

## Basic Auth
If you will be using either the ``--removegroup`` or ``--uploadlog`` options, you must provide the base64 encoded credentials of a Jamf Pro user with the appropriate levels of access.

To get this string, you can enter the following in the terminal:

``echo -n 'user:password' | base64``

where ``user`` and ``password`` are those of the API user.

**NOTE:** It is _**strongly**_ recommended that you create a separate user for this with only the required access. _(See "Deployment Instructions" below)_
  
## Deployment Instructions
This workflow must be created and deployed through Jamf Pro using the following steps: 
- Add Temporary Admin.sh to Jamf Pro
- Create the two policies
	1. A Self Service policy that runs with the script with the 'promote' action (see below)
		- Trigger: Self Service
		- Frequency: Ongoing
		- Scope: _All Computers_ **or** a specified _Static Group_
	2. A policy with a custom trigger (specified in first policy) that demotes the user after the specified amount of time
		- Trigger: Custom
		- Frequency: Ongoing
		- Scope: _All Computers_
- Optional: Create a Static Group to give users one-time access to the Temporary Admin Policy
- Optional: Create an API User with the following permissions
	- Computers - Create
	- File Uploads - Create | Read | Update
	- Static Group - Read | Update