# bazel_rules_vivado: rules for the Xilinx Vivado tooling

This is not a stand-alone rules repository. It relies on 
https://github.com/agoessling/rules_vivado, which builds a Docker container
out of a Vivado installation archive.

It uses an approach I developed for bazel exemplified in
https://github.com/filmil/bazel-rules-bid, which is able to execute a binary
in a docker container as a build action. This means you can have a portable
ephemeral Vivado installation for use in your bazel builds.

Unfortunately, I think it is not possible to distribute this docker container,
so you will need to make it yourself.

Once you do, you can install the prerequisite using:

```
bazel run //prerequisites:vivado -- path_to_the_image.tgz
```

This step will last a couple of hours. But, luckily, it should only be
needed once.  The Vivado container is humongous, over 250GiB, so you need
plenty of disk space to make it work.

# Prior art

* https://github.com/agoessling/rules_vivado: this repository predates
`bazel_rules_vivado`. But, it also adopts a different approach, and requires
you to have a preinstalled Vivado instance.
