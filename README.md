

# JIRA Plugin for MSM

## MSM-JIRA integration

This plugin allows you to **Create**, **View**, **Link** and **Unlink** JIRA issues from within MSM. This is achieved by linking the MSM request number to a custom field that has already been configured within JIRA. This plugin supports linking one or more Marval Requests with one or more JIRA tasks.

## JIRA-MSM integration 

Within JIRA you can set up multiple WebHooks for different transitions. This allows you to move the MSM request status
during transitions. 

**JIRA Base URL**
The JIRA Base URL is the url used to access your instance of JIRA, this is usually in the form of
https://yourworkspacename.atlassian.net/
Where yourworkspacename is your instance name in JIRA that appears in your browser bar.

**Getting JIRA API Key/Password:**

To get the JIRA API key (which is the password in the configuration), navigate here
[Create API Key](https://id.atlassian.com/manage-profile/security/api-tokens)
And Click on **Create API token**
Paste this token into the field **JIRA Password**

**Setting up JIRA WebHooks:**

Within your JIRA instance follow the steps outlined below:

1. The WebHooks link can be found by clicking the **Cog** icon on the top right of JIRA then click **System**. On the left hand menu at the bottom, click on **Web Hooks**.
2. The **Create a WebHook** button is found in the top right.
3. The options can be configured to your requirements however the URL needs to be the Plugin endpoint,
this will be something similar to this, modifying the status=Accepted to the status you would like to move to, replacing at spaces with %20.
## URLRef
4. We also need to provide the action that we want to preform and the name of status we want to move to, this can be achieved by passing the following parameters on the queryString
`action=MoveStatus&status=[StatusName]`.

**Connecting workflow transitions to WebHooks:**

1. Workflows can be found under the workflows section in the issues administration page.
2. Click the edit link of the workflow you want to edit.
3. Select the transition you want to trigger the WebHook on. 
4. Once selected options will appear to the right, select the Post Functions link.
5. The "Add Post Function" link can be found in the top right, select the "Trigger a WebHook" option.
6. A dropdown will contain a list of all your WebHooks, select the one you have just created and click add.

When a JIRA issue is moved to the status with that transition it will call the WebHook created, if the satus is a valid next state the MSM request will move state, 
if the status is not valid a note will be added to the request.

## Compatible Versions

| Plugin  | MSM         | JIRA     | 
|---------|-------------|----------|
| 3.1.3   | 15.7.1+     | Cloud    | 

## Installation

Please see your MSM documentation for information on how to install plugins.

Once the plugin has been installed you will need to configure the following settings within the plugin page:

+ *JIRA Base URL* : The URL (including port) of your JIRA instance. `https://yourworkspacename.atlassian.net/`
+ *JIRA Custom Field Name* : The name of the custom field within JIRA that contains the MSM request number.
> The customer field must be a text field.
+ *JIRA Username* : The username for authentication with JIRA.
+ *JIRA Password* : The password for authentication with JIRA.
+ *Proxy Username* : The username for the system's default proxy (optional).
+ *Proxy Password* : The password for the system's default proxy (optional).
+ *MSM API Key* : The API key for the user created within MSM to perform these actions.
> To get an API key for yourself in Marval, navigate to the top left where your name appears, click on **Profile** and then click the lock icon at the top right in the icon bar which appears under the menu at the top of the page.

As noted above, the JIRA Field MUST be a Text field, otherwise the plugin will not function.

## Usage

The plugin can be launched from the quick menu after you load a request.
The quick search functionality is enabled from your profile menu and available when running a quick search.

## Contributing

We welcome all feedback including feature requests and bug reports. Please raise these as issues on GitHub. If you would like to contribute to the project please fork the repository and issue a pull request.
