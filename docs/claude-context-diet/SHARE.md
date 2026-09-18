# Contexte initial de Claude Code : ~20k → ~7k

Voici une config qui enlève le maximum de choses au démarrage pour faire tomber le contexte initial de Claude Code à ~7k tokens.

À coller dans `~/.claude/settings.json` (sauvegardez l'ancienne avant au cas où).

**Lisez la config et retirez de la liste `deny` les outils que vous utilisez** (`Skill`, `Grep`, `Glob`, `TodoWrite`, `WebSearch`, `Agent` sont denied par exemple). Il ne reste que `Bash`, `Read`, `Edit` et `Write`.

Tips repris du AI coding crash course de Matt Pocock. Des questions, dites-moi 🙂

```json
{
  "env": {
    "ENABLE_CLAUDEAI_MCP_SERVERS": "false"
  },
  "disableClaudeAiConnectors": true,
  "disableWorkflows": true,
  "disableBundledSkills": true,
  "disableArtifact": true,
  "includeGitInstructions": false,
  "autoMemoryEnabled": false,
  "permissions": {
    "deny": [
      "Glob",
      "Grep",
      "NotebookEdit",
      "WebFetch",
      "WebSearch",
      "Task",
      "TodoWrite",
      "TaskCreate",
      "TaskUpdate",
      "TaskGet",
      "TaskList",
      "TaskStop",
      "Skill",
      "REPL",
      "AskUserQuestion",
      "SendUserMessage",
      "Agent",
      "ListAgents",
      "ShareOnboardingGuide",
      "Artifact",
      "Workflow",
      "ReportFindings",
      "ScheduleWakeup",
      "DesignSync",
      "CronCreate",
      "CronDelete",
      "CronList",
      "PushNotification",
      "RemoteTrigger",
      "EnterPlanMode",
      "ExitPlanMode",
      "EnterWorktree",
      "ExitWorktree",
      "Monitor",
      "TaskOutput",
      "SendMessage",
      "EndConversation",
      "BashOutput",
      "KillShell"
    ]
  }
}
```
