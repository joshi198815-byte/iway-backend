import { IsInt, Max, Min } from 'class-validator';

export class UpdateCutoffPreferenceDto {
  @IsInt()
  @Min(1)
  @Max(7)
  preferredCutoffDay!: number;
}
