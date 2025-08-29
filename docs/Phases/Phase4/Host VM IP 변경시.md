## Host VM IP가 바뀌면 반드시 수정할 것:

DevStack local.conf → HOST_IP 수정 후 재실행

clouds.yaml (로컬 & Runner 계정) → auth_url 수정

GitLab 서버 external_url 수정 + git remote URL 변경

GitLab Runner 재등록 (unregister & register)
