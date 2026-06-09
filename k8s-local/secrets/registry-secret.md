kubectl create secret docker-registry registry-secret \
  --docker-server=registry.manjilgautam.com.np \
  --docker-username=<username> \
  --docker-password=<password> \
  -n django-auth