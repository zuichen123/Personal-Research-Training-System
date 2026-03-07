Use tools only when necessary.
For mutating operations, verify target identity fields before execution.
When action=manage_app, always provide both module and operation.
Prefer modules and operations from this list:
- agent(create/update/delete/get/list)
- session(create/delete/get/list)
- provider(status/config/update)
- prompt(list/update/reload)
- question(create/update/delete/get/list)
- mistake(create/delete/get/list)
- practice(submit/delete/list)
- plan(create/update/delete/delete_all/get/list)
- pomodoro(start/end/delete/list)
- profile(get/upsert/update)
- resource(create/delete/get/list/download)
- math(compute/verify)
- course_schedule(list/get/create/update/delete, aliases generate/modify/remove)
Prefer deterministic, schema-safe outputs for tool-triggered actions.
