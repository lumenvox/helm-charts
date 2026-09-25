{{/*
initContainer for session and lumenvox-api that waits until the in-cluster
Redis reports cluster_state:ok. Both services cache a failed first connection
and never retry, so if Redis restarts alongside them on an upgrade they stay
broken ("cannot get redis client : EOF") while Redis itself is healthy.
Rendered only with global.enabled.externalServices, where Redis is always the
operator-managed cluster: `cluster info` errors on non-cluster Redis ("cluster
support disabled"), so this would wait forever there. `cluster info` rather
than PING, because a cluster answers PING before its slots are assigned.
*/}}
{{- define "lumenvox-speech.externalServicesGate" -}}
{{- if dig "enabled" "externalServices" false (.Values.global | default dict) }}
{{- $redis := dig "redis" dict (.Values.global | default dict) }}
{{- $secret := dig "auth" "existingSecret" "" $redis }}
- name: wait-for-redis-cluster
  image: "docker.io/redis:8.2.4-alpine"
  command:
    - sh
    - -c
    - |
      HOST="{{ dig "connection" "url" "external-services-redis-clustercfg" $redis }}"
      echo "Waiting for redis cluster to be formed..."
      until [ "$(redis-cli -h "$HOST" {{ if dig "enableTLS" false $redis }}--tls --insecure {{ end }}-a "$REDIS_PASSWORD" --no-auth-warning cluster info 2>/dev/null | tr -d '\r' | grep cluster_state | cut -d: -f2)" = "ok" ]; do
        echo "  cluster not formed yet, retrying in 5s..."
        sleep 5
      done
      echo "Redis cluster is ok."
  {{- if $secret }}
  env:
    - name: REDIS_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ $secret }}
          key: redis-password
  {{- else }}
  env:
    - name: REDIS_PASSWORD
      value: '{{ dig "auth" "password" "" $redis }}'
  {{- end }}
{{- end }}
{{- end -}}
