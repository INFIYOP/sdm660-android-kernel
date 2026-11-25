/* Minimal static init for a mainline boot test. MUST be built for aarch64 (aarch64-linux-gnu-gcc -static).
 *
 * Not Android and not postmarketOS. It proves two things only: the bootloader accepted the appended DTB
 * (msm-id/board-id match) and the kernel reached userspace.
 *
 * The phone has no serial console, so the result is kept in three places:
 *   - the screen (/dev/console and /dev/tty0), repeated for 60 seconds so it can be read or photographed
 *   - the kernel log (/dev/kmsg), which the ramoops/pstore console buffer also captures
 *   - after the countdown the phone RESTARTS (warm reset) instead of powering off, so RAM is preserved and
 *     the normal OS that boots next can read the mainline kernel log from /sys/fs/pstore/console-ramoops-0
 *     (docs/FIRST_BOOT_TEST.md). Build with -DPOWER_OFF_AT_END to power off instead.
 *
 * The initramfs holds only this binary, so /dev, /proc and /sys do not exist and are created here.
 * (Without that the mounts fail, /dev/console cannot be opened, and the program prints nothing.)
 */
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/reboot.h>
#include <linux/reboot.h>

static void say(const char *msg)
{
	static const char *const sinks[] = { "/dev/kmsg", "/dev/console", "/dev/tty0" };
	char line[512];
	int i, fd, n;

	for (i = 0; i < 3; i++) {
		fd = open(sinks[i], O_WRONLY | O_NOCTTY);
		if (fd < 0)
			continue;
		n = snprintf(line, sizeof(line), "%s%s\n", i == 0 ? "<5>init: " : "", msg);
		if (write(fd, line, n) < 0) { /* nothing useful to do */ }
		close(fd);
	}
}

static void say_file(const char *label, const char *path)
{
	char buf[400], out[480];
	ssize_t n;
	int fd = open(path, O_RDONLY);

	if (fd < 0) {
		say(label);
		return;
	}
	n = read(fd, buf, sizeof(buf) - 1);
	close(fd);
	if (n < 0)
		n = 0;
	buf[n] = 0;
	if (n > 0 && buf[n - 1] == '\n')
		buf[n - 1] = 0;
	snprintf(out, sizeof(out), "%s: %s", label, buf);
	say(out);
}

int main(void)
{
	char msg[96];
	int i;

	mkdir("/dev", 0755);
	mkdir("/proc", 0555);
	mkdir("/sys", 0555);
	mount("devtmpfs", "/dev", "devtmpfs", 0, NULL);
	mount("proc", "/proc", "proc", 0, NULL);
	mount("sysfs", "/sys", "sysfs", 0, NULL);

	say("MAINLINE BOOT OK - kernel reached userspace");
	say_file("version", "/proc/version");
	say_file("cmdline", "/proc/cmdline");

	for (i = 60; i > 0; i--) {
#ifdef POWER_OFF_AT_END
		snprintf(msg, sizeof(msg), "MAINLINE BOOT OK - powering off in %d s", i);
#else
		snprintf(msg, sizeof(msg), "MAINLINE BOOT OK - restarting in %d s", i);
#endif
		say(msg);
		sleep(1);
	}

	sync();
#ifdef POWER_OFF_AT_END
	reboot(LINUX_REBOOT_CMD_POWER_OFF);
#else
	reboot(LINUX_REBOOT_CMD_RESTART);
#endif
	for (;;)
		pause();
}
