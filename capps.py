#!/usr/bin/env python3
import re
import json
import yaml
import subprocess
import time
import logging
import random
import string
import jinja2
import os
from argparse import ArgumentParser
from shutil import copyfile

user_id = str(os.getuid())
podman_path = "/usr/bin/podman"
wayland_display = os.path.expandvars("$WAYLAND_DISPLAY")
xdg_runtime_path = os.path.expandvars("$XDG_RUNTIME_DIR")
pulse_socket = "/run/user/" + user_id + "/pulse/native"
home_dir = os.path.expanduser("~")


def load_config(path="config.yml"):
    logger.info("Loading config: " + path)
    with open(path, "r") as stream:
        try:
            return yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)


def podman_image_inspect(id):
    logger.info("Inspecting image: " + id)
    check_image = [podman_path, "image", "inspect", "--format", "json", id]
    try:
        image_json = json.loads(
            subprocess.check_output(check_image, shell=False).decode()
        )
    except subprocess.CalledProcessError:
        image_json = ""
    return image_json


def podman_container_inspect(id):
    logger.info("Inspecting container: " + id)
    check_container = [podman_path, "container", "inspect", "--format", "json", id]
    logger.debug(check_container)
    try:
        container_json = json.loads(
            subprocess.check_output(
                check_container, shell=False, stderr=subprocess.STDOUT
            ).decode()
        )[0]
    except subprocess.CalledProcessError:
        container_json = ""
    return container_json


def podman_stats(id):
    container_stats = [podman_path, "stats", "--no-stream", "--format", "json", id[0]]
    logger.debug(container_stats)
    try:
        json_stats = json.loads(
            subprocess.check_output(
                container_stats, shell=False, stderr=subprocess.STDOUT
            ).decode()
        )
    except subprocess.CalledProcessError:
        logger.info("No stats for container: " + " ".join(id))
        json_stats = ""
    logger.info("collected stats for container: " + " ".join(id))
    logger.debug(json_stats)
    return json_stats


def check_images(config, name):
    podman_image_list = [podman_path, "image", "list", "--format", "json"]
    get_image = subprocess.check_output(podman_image_list, shell=False).decode()
    image_list = json.loads(get_image)
    for image in image_list:
        if not "Dangling" in image:
            image_name = config["repo"] + "/" + name + ".*"
            pattern = re.findall(image_name, image["Names"][0])
            if image["Names"][0] in pattern:
                now = time.time()
                age = int((now - image["Created"]) / 60 / 60 / 24)
                version = image["Names"][0]
                logger.info(
                    "Found image: " + image["Names"][0] + " " + str(age) + " Days old"
                )
                return age


def build_image(image, name):
    build_cmd = [
        podman_path,
        "image",
        "build",
        "--build-arg=USER=" + str(user_id),
        "--pull-always",
        "--rm",
        "--force-rm",
        "--no-cache",
        "--squash-all",
        "--quiet",
        "-t",
        image["repo"] + "/" + name,
        "-f",
        image["path"] + image["file"],
        image["path"],
    ]
    version_cmd = [
        podman_path,
        "run",
        "--rm",
        "-it",
        "--entrypoint",
        "bash",
        image["repo"] + "/" + name,
        "-c",
        image["versioncmd"],
    ]
    logger.debug("Version command: " + str(version_cmd))
    try:
        old_version = (
            subprocess.check_output(version_cmd, shell=False).decode().strip("\n")
        )
        logger.info(
            "Old Version for for: " + image["repo"] + "/" + name + ": " + old_version
        )
    except subprocess.CalledProcessError as e:
        logger.info(
            "Old Version for for: " + image["repo"] + "/" + name + ": " + "Not Found!"
        )
    logger.debug("Build command: " + str(build_cmd))
    logger.info("Starting build for: " + image["repo"] + "/" + name)
    try:
        new_image = subprocess.check_output(build_cmd, shell=False).decode().strip("\n")
    except subprocess.CalledProcessError:
        new_image = ""
    logger.info("Build image for: " + name + ": [" + new_image + "]")
    new_version = (
        subprocess.check_output(version_cmd, shell=False)
        .decode()
        .strip("\n")
        .strip("\r")
    )
    tag_cmd = [
        podman_path,
        "image",
        "tag",
        new_image,
        image["repo"] + "/" + name + ":" + new_version,
    ]
    logger.debug(tag_cmd)
    logger.info(
        "Tagging new Version for for: " + image["repo"] + "/" + name + ":" + new_version
    )
    try:
        tag_image_version = (
            subprocess.check_output(tag_cmd, shell=False).decode().strip("\n")
        )
    except subprocess.CalledProcessError:
        tag_image_version = ""
        logger.warning(
            "Tagging new Version for for: "
            + image["repo"]
            + "/"
            + name
            + ":"
            + new_version
            + " failed"
        )
    return new_image


def run_image(container, name):
    run_cmd = craft_run_cmd(container, name)
    logger.debug(run_cmd)
    try:
        container_id = (
            subprocess.check_output(run_cmd, shell=False).decode().strip("\n")
        )
    except subprocess.CalledProcessError:
        container_id = ""
    container_json = podman_container_inspect(container_id)
    logger.debug(container_json)
    logger.info("Started " + name + " in container: " + container_id)
    return container_id


def craft_run_cmd(container, name):
    args = []
    for param, arg in container["permissions"].items():
        if type(arg) is list and "volume" == param:
            for nest in arg:
                if "$XDG_RUNTIME_DIR" in nest:
                    nest = nest.replace("$XDG_RUNTIME_DIR", xdg_runtime_path)
                if "$WAYLAND_DISPLAY" in nest:
                    nest = nest.replace("$WAYLAND_DISPLAY", wayland_display)
                if "$HOME" in nest:
                    nest = nest.replace("$HOME", home_dir)
                if "$UID" in nest:
                    nest = nest.replace("$UID", user_id)
                args.append("--" + param + "=" + nest)
        elif type(arg) is list:
            for nest in arg:
                args.append("--" + param + "=" + nest)
        elif type(arg) is bool:
            args.append("--" + param + "=" + str(arg).lower())
        else:
            args.append("--" + param + "=" + arg)
    random_end = "-" + str(random.randint(1000, 9999))
    run_cmd = [
        podman_path,
        "run",
        "--rm",
        "-d",
        "--hostname",
        name,
        "--name=" + name + random_end,
    ]
    for arg in args:
        run_cmd.append(arg)
    run_cmd.append(container["repo"] + "/" + name)
    return run_cmd


def install_desktop(container, name):
    run_cmd = craft_run_cmd(container, name)
    shell_run_cmd= "" # expand run command to one long string
    for cmd in run_cmd:
        shell_run_cmd += cmd + " "
    template = (
        jinja2.Environment(
            loader=jinja2.FileSystemLoader(searchpath="./"), autoescape=True
        )
        .get_template("template.desktop.j2")
        .render(name=name, shell_run_cmd=shell_run_cmd)
    )
    desktop_file_path = os.path.join(
        home_dir, ".local/share/applications/", name + "-podman.desktop"
    )
    icon_src_path = container["path"] + container["icon"]
    icon_file_path = os.path.join(home_dir, ".local/share/icons/", name + "-podman.png")
    copyfile(icon_src_path, icon_file_path)
    logger.info("Copy icon from " + icon_src_path + " to: " + icon_file_path)
    logger.info("Installing dektop file for " + name + " in: " + desktop_file_path)
    desktop_file = open(desktop_file_path, "w")
    desktop_file.write(template)
    desktop_file.close()
    logger.debug("Installed Desktop file: \n" + template)


def get_args():
    parser = ArgumentParser(description="Start podman container apps.")
    parser.add_argument(
        "-a",
        "--application-list",
        metavar="app1 app2 ...",
        action="extend",
        nargs="+",
        default=[],
        help="List of applications to run as defined in config file",
    )
    parser.add_argument(
        "-c",
        "--config",
        metavar="/path/to/config.yaml",
        default="config.yml",
        help="Path to config file (defaults to config.yaml)",
    )
    parser.add_argument(
        "-b",
        "--build",
        default=False,
        action="store_true",
        help="(re)build list of provided apps",
    )
    parser.add_argument(
        "-r",
        "--run",
        default=True,
        action="store_true",
        help="run containers of all provided apps",
    )
    parser.add_argument(
        "-i",
        "--install",
        default=False,
        action="store_true",
        help="install as desktop application",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        default=False,
        action="store_true",
        help="enable verbose log output",
    )
    parser.add_argument(
        "-s",
        "--stats",
        default=False,
        action="store_true",
        help="enable container stats output",
    )
    parser.add_argument(
        "-d",
        "--debug",
        default=False,
        action="store_true",
        help="enable debug log output",
    )
    parser.add_argument(
        "-l",
        "--list",
        default=False,
        action="store_true",
        help="print available container",
    )
    return parser.parse_args()


def set_logging(args):
    if args.debug:
        logging.basicConfig(
            level=logging.DEBUG, format="[%(asctime)s]: [%(levelname)s]: %(message)s"
        )
    elif args.verbose:
        logging.basicConfig(
            level=logging.INFO, format="[%(asctime)s]: [%(levelname)s] %(message)s"
        )
    else:
        logging.basicConfig(
            level=logging.WARNING, format="[%(levelname)s]: %(message)s"
        )
    return logging.getLogger(__name__)


def container_loop(container, args):
    for name in args.application_list:
        if name in config["container"]:
            container = config["container"][name]
            image = check_images(container, name)
            if image is None:
                logger.warning(
                    "Starting build for " + name + " since no image was found!"
                )
                build_image(container, name)
            elif image > 60 * 24 * 7:
                logger.warning(
                    "Starting build for "
                    + name
                    + " since the image is "
                    + str(image)
                    + " minutes old!"
                )
                build_image(container, name)
            if args.build:
                logger.warning(
                    "(Re)building image for " + name + "! This may take a while."
                )
                build_image(container, name)
            if args.install:
                install_desktop(container, name)
            if args.run and image is None:
                new_container = run_image(container, name)
                started_container.append(new_container)
        else:
            logger.warning("No config for container " + name + " found!")


def list_containers():
    podman_image_list = [podman_path, "image", "list", "--format", "json"]
    get_image = subprocess.check_output(podman_image_list, shell=False).decode()
    image_list = json.loads(get_image)

    print("Available Containers in config:")
    for container in config["container"].items():
        print(container[0], end=": ", flush=True)
        print("\tMem: " + container[1]["permissions"]["memory"], end=", ", flush=True)
        print("\tCapabilities: ", end=" ", flush=True)
        try:
            print(container[1]["permissions"]["cap-add"], end=", ", flush=True)
            print("\tcap-drop: " + container[1]["permissions"]["cap-drop"])
        except KeyError:
            print("\tcap-drop: " + container[1]["permissions"]["cap-drop"])
        print("Available images on host for " + container[0] + ": ")
        for image in image_list:
            if not "Dangling" in image:
                image_name = container[1]["repo"] + "/" + container[0] + ".*"
                inspected_image = podman_image_inspect(image["Id"])
                pattern = re.findall(image_name, inspected_image[0]["RepoTags"][0])
                if image["Names"][0] in pattern:
                    now = time.time()
                    age = int((now - image["Created"]) / 60)
                    print(image["Names"], end="\t")
                    print(
                        "Entrypoint: "
                        + str(inspected_image[0]["Config"]["Entrypoint"]),
                        end="\t",
                    )
                    print(
                        "Size: "
                        + str(int(inspected_image[0]["Size"] / 1000 / 1000))
                        + " MB",
                        end="\t",
                    )
                    print(" " + "\t" + str(age) + " Minutes old.")
        print()


def status_loop(container, args):
    if args.stats:
        logger.info(
            "Printing container stats for containers: " + " ".join(started_container)
        )
        print("NAME\t\t\tMEM\t\t\t  CPU\t READ/WRITE   PIDS")
        while len(started_container) > 0:
            for container in started_container:
                if podman_container_inspect(container) == "":
                    logger.info(
                        "Removing container:"
                        + container
                        + " because it is no longer present"
                    )
                    started_container.remove(container)
            if len(started_container) > 0:
                stats = podman_stats(started_container)
                for container in stats:
                    print(
                        container["name"] + ":\t",
                        container["mem_usage"],
                        "/",
                        container["mem_percent"],
                        "\t",
                        container["cpu_percent"],
                        "\t",
                        container["block_io"],
                        container["pids"],
                    )
            else:
                logger.warning("All containers are gone!")
            time.sleep(2)


if __name__ == "__main__":
    args = get_args()
    logger = set_logging(args)
    config = load_config(args.config)
    started_container = []
    container = config["container"].items()
    if args.list:
        list_containers()
    container_loop(container, args)
    status_loop(container, args)
