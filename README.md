# aports

This repo builds and uploads the alpine packages location in the `ig` folder.

For now the packages are just uploaded to an image, from which the images can be extracted:

```bash
# create the container to copy the packages from
docker create --name aports ghcr.io/imagegenius/aports:latest blah

# copy the packages to the current directory
docker cp aports:/out/* .

# cleanup
docker rm aports
docker rmi ghcr.io/imagegenius/aports:latest
```
