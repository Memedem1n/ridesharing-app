// User Domain Entity
// Pure business logic - no framework dependencies

export interface UserProps {
    id: string;
    phone: string;
    email: string;
    passwordHash: string;
    fullName: string;
    dateOfBirth?: Date;
    gender?: 'male' | 'female' | 'other' | 'prefer_not_to_say';
    profilePhotoUrl?: string;
    bio?: string;
    ratingAvg: number;
    ratingCount: number;
    totalTrips: number;
    verificationStatus: VerificationStatus;
    preferences: UserPreferences;
    womenOnlyMode: boolean;
    bannedUntil?: Date;
    penaltyScore: number;
    walletBalance: number;
    referralCode: string;
    referredBy?: string;
    createdAt: Date;
    updatedAt: Date;
}

export interface VerificationStatus {
    phone: boolean;
    email: boolean;
    identity: boolean;
    selfie: boolean;
    vehicle: boolean;
}

export interface UserPreferences {
    music?: string;
    smoking?: boolean;
    pets?: boolean;
    chattiness?: 'quiet' | 'normal' | 'chatty';
    ac?: boolean;
}

export class User {
    private constructor(private readonly props: UserProps) { }

    static create(props: UserProps): User {
        return new User(props);
    }

    // Getters
    get id(): string { return this.props.id; }
    get phone(): string { return this.props.phone; }
    get email(): string { return this.props.email; }
    get fullName(): string { return this.props.fullName; }
    get ratingAvg(): number { return this.props.ratingAvg; }
    get isVerified(): boolean {
        const status = this.props.verificationStatus;
        return status.phone && status.email;
    }
    get isFullyVerified(): boolean {
        const status = this.props.verificationStatus;
        return status.phone && status.email && status.identity && status.selfie;
    }
    get isBanned(): boolean {
        return this.props.bannedUntil ? new Date() < this.props.bannedUntil : false;
    }

    // Methods
    canPublishTrips(): boolean {
        return this.isVerified && !this.isBanned && this.props.penaltyScore < 10;
    }

    canUseWomenOnlyMode(): boolean {
        return this.props.gender === 'female' && this.props.womenOnlyMode;
    }

    toJSON(): UserProps {
        return { ...this.props };
    }
}
