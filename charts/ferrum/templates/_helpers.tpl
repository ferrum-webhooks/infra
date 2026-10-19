{{- define "ferrum.image" -}}
{{ .root.Values.image.registry }}/{{ .root.Values.image.organization }}/{{ .name }}:{{ .root.Values.image.tag }}
{{- end -}}

{{- define "ferrum.labels" -}}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/part-of: ferrum
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
helm.sh/chart: {{ .root.Chart.Name }}-{{ .root.Chart.Version }}
{{- end -}}

{{/* DB connection env shared by gateway, worker and the migration Job. Password only ever comes from a Secret. */}}
{{- define "ferrum.dbEnv" -}}
- {name: DB_HOST, value: {{ .Values.database.host | quote }}}
- {name: DB_PORT, value: {{ .Values.database.port | quote }}}
- {name: DB_NAME, value: {{ .Values.database.name | quote }}}
- {name: DB_USER, value: {{ .Values.database.user | quote }}}
- name: DB_PASSWORD
  valueFrom: {secretKeyRef: {name: {{ .Values.database.passwordSecret.name }}, key: {{ .Values.database.passwordSecret.key }}}}
{{- end -}}

{{- define "ferrum.imagePullSecrets" -}}
{{- with .Values.image.pullSecrets }}
imagePullSecrets:
{{ toYaml . | indent 2 }}
{{- end }}
{{- end -}}
