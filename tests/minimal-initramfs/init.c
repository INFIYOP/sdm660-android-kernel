/* Minimal static init for a mainline boot test.
 *
 * Not Android and not postmarketOS. It proves two things only: the bootloader
 * accepted the appended DTB (msm-id/board-id match), and the kernel reached
 * userspace. It prints a marker on the console, then powers off so that
 * `fastboot boot` returns.
 */
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/mount.h>
#include <sys/reboot.h>
#include <linux/reboot.h>

int main(void)
{
int fd;

mount("devtmpfs", "/dev", "devtmpfs", 0, NULL);
mount("proc", "/proc", "proc", 0, NULL);
mount("sysfs", "/sys", "sysfs", 0, NULL);

fd = open("/dev/console", O_WRONLY);
if (fd >= 0) {
dprintf(fd, "\nMAINLINE BOOT OK - kernel reached userspace\n");
close(fd);
}
write(1, "MAINLINE BOOT OK\n", 17);

sync();
sleep(2);
reboot(LINUX_REBOOT_CMD_POWER_OFF);
for (;;)
pause();
}
