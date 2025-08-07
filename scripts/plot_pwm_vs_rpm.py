import matplotlib.pyplot as plt

# Sauvegarde du graphique pwm_rpm_test.log en .png pour lecture depuis le serveur
def parse_log_file(filename):
    pwm = []
    rpm = []
    with open(filename, 'r') as f:
        for line in f:
            # Exemple de ligne attendue : "PWM: 20 %, RPM: 3000"
            if "PWM" in line and "RPM" in line:
                parts = line.strip().split(',')
                try:
                    pwm_part = parts[0].split(':')[1].strip().replace(' %', '')
                    rpm_part = parts[1].split(':')[1].strip()
                    pwm.append(int(pwm_part))
                    rpm.append(int(rpm_part))
                except (IndexError, ValueError):
                    # ignore lines malformées
                    continue
    return pwm, rpm

def main():
    pwm, rpm = parse_log_file("pwm_rpm_test.log")

    plt.figure(figsize=(8, 5))
    plt.plot(pwm, rpm, marker='o', linestyle='-', color='blue')
    plt.title("Relation PWM (%) vs Vitesse ventilateur (RPM)")
    plt.xlabel("PWM (%)")
    plt.ylabel("Vitesse (RPM)")
    plt.grid(True)

    plt.savefig("pwm_vs_rpm.png")
    print("Graphique sauvegardé sous pwm_vs_rpm.png")

if __name__ == "__main__":
    main()
