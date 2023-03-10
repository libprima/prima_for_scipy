module test_solver_mod
!--------------------------------------------------------------------------------------------------!
! This module tests LINCOA on a few simple problems.
!
! Coded by Zaikun ZHANG (www.zhangzk.net).
!
! Started: September 2021
!
! Last Modified: Thursday, January 26, 2023 PM12:35:01
!--------------------------------------------------------------------------------------------------!

implicit none
private
public :: test_solver


contains


subroutine test_solver(probs, mindim, maxdim, dimstride, nrand, randseed)

use, non_intrinsic :: lincoa_mod, only : lincoa
use, non_intrinsic :: consts_mod, only : RP, IK, TWO, TEN, ZERO, REALMAX
use, non_intrinsic :: debug_mod, only : validate
use, non_intrinsic :: infnan_mod, only : is_neginf
use, non_intrinsic :: linalg_mod, only : eye
use, non_intrinsic :: memory_mod, only : safealloc
use, non_intrinsic :: noise_mod, only : noisy, noisy_calfun, orig_calfun
use, non_intrinsic :: param_mod, only : MINDIM_DFT, MAXDIM_DFT, DIMSTRIDE_DFT, NRAND_DFT, RANDSEED_DFT
use, non_intrinsic :: prob_mod, only : PNLEN, PROB_T, construct, destruct
use, non_intrinsic :: rand_mod, only : setseed, rand, randn
use, non_intrinsic :: string_mod, only : trimstr, istr

implicit none

character(len=PNLEN), intent(in), optional :: probs(:)
integer(IK), intent(in), optional :: dimstride
integer(IK), intent(in), optional :: maxdim
integer(IK), intent(in), optional :: mindim
integer(IK), intent(in), optional :: nrand
integer, intent(in), optional :: randseed

character(len=*), parameter :: bigprob = 'bigprob'
character(len=*), parameter :: solname = 'lincoa'
character(len=*), parameter :: srname = 'TEST_LINCOA'
character(len=PNLEN) :: probname
character(len=PNLEN) :: probs_loc(100)  ! Maximal number of problems to test: 100
character(len=PNLEN) :: fix_dim_probs(size(probs_loc))  ! Problems with fixed dimensions
integer :: randseed_loc
integer :: rseed
integer(IK), parameter :: bign = 400_IK
integer(IK) :: dim_list(100)  ! Maximal number of dimensions to test: 100
integer(IK) :: dimstride_loc
integer(IK) :: idim
integer(IK) :: iprint
integer(IK) :: iprob
integer(IK) :: irand
integer(IK) :: m
integer(IK) :: maxdim_loc
integer(IK) :: maxfilt
integer(IK) :: maxfun
integer(IK) :: maxhist
integer(IK) :: mindim_loc
integer(IK) :: n
integer(IK) :: ndim
integer(IK) :: nprobs
integer(IK) :: npt
integer(IK) :: nnpt
integer(IK) :: npt_list(10)
integer(IK) :: nrand_loc
logical :: test_bigprob = .false.
real(RP) :: cstrv
real(RP) :: ctol
real(RP) :: f
real(RP) :: f_unc
real(RP) :: ftarget
real(RP) :: rhobeg
real(RP) :: rhoend
real(RP), allocatable :: Aineq(:, :)
real(RP), allocatable :: bineq(:)
real(RP), allocatable :: chist(:)
real(RP), allocatable :: fhist(:)
real(RP), allocatable :: x(:)
real(RP), allocatable :: x0(:)
real(RP), allocatable :: x_unc(:)
real(RP), allocatable :: xhist(:, :)
type(PROB_T) :: prob

if (present(probs)) then
    nprobs = int(size(probs), kind(nprobs))
    probs_loc(1:nprobs) = probs
else
    nprobs = 7
    probs_loc(1:nprobs) = ['tetrahedron', 'ptinsq     ', 'chebyquad  ', 'chrosen    ', 'trigsabs   ', 'trigssqs   ', 'vardim     ']
end if
fix_dim_probs = '           '   ! Initialization, or compilers complain that the array is not (completely) defined.
fix_dim_probs(1:1) = ['tetrahedron']

if (present(mindim)) then
    mindim_loc = mindim
else
    mindim_loc = MINDIM_DFT
end if

if (present(maxdim)) then
    maxdim_loc = maxdim
else
    maxdim_loc = MAXDIM_DFT
end if

if (present(dimstride)) then
    dimstride_loc = dimstride
else
    dimstride_loc = DIMSTRIDE_DFT
end if

if (present(nrand)) then
    nrand_loc = nrand
else
    nrand_loc = NRAND_DFT
end if

if (present(randseed)) then
    randseed_loc = randseed
else
    randseed_loc = RANDSEED_DFT
end if


! Test the big problem
if (test_bigprob) then
    probname = bigprob
    n = bign
    do irand = 1, 1  ! The test is expensive
        rseed = int(sum(istr(solname)) + sum(istr(probname)) + n + irand + RP + randseed_loc)
        call setseed(rseed)
        m = int(min(int(10.0_RP * rand() * real(n, RP)), 10**min(range(0), range(0_IK))), IK)
        call construct(prob, probname, n, m)
        npt = max(n + 2_IK, int(5.0 * rand() * real(n, RP), kind(npt)))
        iprint = 2
        if (int(npt) + 800 > huge(0_IK)) then
            maxfun = huge(0_IK)
        else
            maxfun = npt + int(800.0_RP * rand(), IK)
        end if
        maxhist = maxfun
        maxfilt = int(TWO * rand() * real(maxfun, RP), kind(maxfilt))
        if (rand() <= 0.5) then
            ctol = TEN**(-abs(5.0 * randn()))
        else
            ctol = ZERO
        end if
        ftarget = -REALMAX
        rhobeg = noisy(prob % Delta0)
        rhoend = max(1.0E-6_RP, rhobeg * 1.0E1_RP**(4.0_RP * rand() - 3.5_RP))
        call safealloc(x, n) ! Not all compilers support automatic allocation yet, e.g., Absoft.
        x = noisy(prob % x0)
        orig_calfun => prob % calfun
        call safealloc(Aineq, int(size(prob % Aineq, 1), IK), int(size(prob % Aineq, 2), IK))
        Aineq = prob % Aineq
        call safealloc(bineq, int(size(prob % bineq), IK))
        bineq = prob % bineq

        print '(/1A, I0, 1A, I0, 1A, I0, 1A, I0, 1A, I0)', &
           & trimstr(probname)//': N = ', n, ' NPT = ', npt, ' M = ', size(Aineq, 2), ', MAXFUN = ', maxfun, ', Random test ', irand

        call lincoa(noisy_calfun, x, f, cstrv=cstrv, A=Aineq, b=bineq, &
            & npt=npt, rhobeg=rhobeg, rhoend=rhoend, maxfun=maxfun, maxhist=maxhist, fhist=fhist, xhist=xhist,&
            & chist=chist, ctol=ctol, ftarget=ftarget, maxfilt=maxfilt, iprint=iprint)

        deallocate (x)
        nullify (orig_calfun)
        ! DESTRUCT deallocates allocated arrays/pointers and nullify the pointers. Must be called.
        call destruct(prob)  ! Destruct the testing problem.
    end do

else

    do iprob = 1, nprobs
        probname = probs_loc(iprob)
        if (any(probname == fix_dim_probs)) then
            call construct(prob, probname)  ! Construct the testing problem.
            ndim = 1
            dim_list(1) = prob % n
        else
            ndim = (maxdim_loc - mindim_loc) / dimstride_loc + 1_IK
            dim_list(1:ndim) = mindim_loc + dimstride_loc*[(idim - 1_IK, idim=1_IK, ndim)]
        end if
        if (trim(probname) == 'ptinsq') then
            dim_list(1:ndim) = int(ceiling(real(dim_list(1:ndim)) / 2.0) * 2, IK)  ! Must be even
        end if
        do idim = 1, ndim
            if (any(probname == fix_dim_probs)) then
                call construct(prob, probname)
            else
                call construct(prob, probname, n=dim_list(idim))
            end if
            n = prob % n

            ! NPT_LIST defines some extreme values of NPT.
            nnpt = 10
            npt_list(1:nnpt) = [1_IK, &
                & n + 1_IK, n + 2_IK, n + 3_IK, &
                & 2_IK * n, 2_IK * n + 1_IK, 2_IK * n + 2_IK, &
                & (n + 1_IK) * (n + 2_IK) / 2_IK - 1_IK, (n + 1_IK) * (n + 2_IK) / 2_IK, &
                & (n + 1_IK) * (n + 2_IK) / 2_IK + 1_IK]
            do irand = 1, nnpt + max(0_IK, nrand_loc)
                ! Initialize the random seed using N, IRAND, RP, and RANDSEED_LOC. Do not include IK so
                ! that the results for different IK are the same.
                rseed = int(sum(istr(solname)) + sum(istr(probname)) + n + irand + RP + randseed_loc)
                call setseed(rseed)
                if (irand <= nnpt) then
                    npt = npt_list(irand)
                else
                    npt = int(TEN * rand() * real(n, RP), kind(npt))
                end if
                if (rand() <= 0.2) then
                    npt = 0
                end if
                !iprint = int(sign(min(3.0_RP, 1.5_RP * abs(randn())), randn()), kind(iprint))
                iprint = 2
                maxfun = int(2.0E2_RP * rand() * real(n, RP), kind(maxfun))
                if (rand() <= 0.2) then
                    maxfun = 0
                end if
                maxhist = int(TWO * rand() * real(max(10_IK * n, maxfun), RP), kind(maxhist))
                if (rand() <= 0.2) then
                    maxhist = -maxhist
                end if
                maxfilt = int(TWO * rand() * real(maxfun, RP), kind(maxfilt))
                if (rand() <= 0.2) then
                    maxfilt = 0
                end if
                if (rand() <= 0.2) then
                    ctol = randn() * TEN**(-abs(TWO * randn()))
                elseif (rand() <= 0.2) then  ! Note that the value of rand() changes.
                    ctol = REALMAX
                else
                    ctol = ZERO
                end if
                if (rand() <= 0.2) then
                    ftarget = -TEN**abs(TWO * randn())
                elseif (rand() <= 0.2) then  ! Note that the value of rand() changes.
                    ftarget = REALMAX
                else
                    ftarget = -REALMAX
                end if

                rhobeg = noisy(prob % Delta0)
                rhoend = max(1.0E-6_RP, rhobeg * 1.0E1_RP**(6.0_RP * rand() - 5.0_RP))
                if (rand() <= 0.2) then
                    rhoend = rhobeg
                elseif (rand() <= 0.2) then  ! Note that the value of rand() changes.
                    rhobeg = ZERO
                end if

                call safealloc(x0, n) ! Not all compilers support automatic allocation yet, e.g., Absoft.
                x0 = noisy(prob % x0)

                orig_calfun => prob % calfun

                if (prob % probtype == 'b') then
                    call safealloc(Aineq, n, 2_IK * n)
                    Aineq(:, 1_IK:n) = eye(n)
                    Aineq(:, n + 1_IK:2_IK * n) = -eye(n)
                    call safealloc(bineq, 2_IK * n)
                    bineq = [prob % ub, -prob % lb]
                else
                    call safealloc(Aineq, int(size(prob % Aineq, 1), IK), int(size(prob % Aineq, 2), IK))
                    Aineq = prob % Aineq
                    call safealloc(bineq, int(size(prob % bineq), IK))
                    bineq = prob % bineq
                end if

                print '(/1A, I0, 1A, I0, 1A, I0, 1A, I0)', trimstr(probname)//': N = ', n, ' NPT = ', npt, &
                    & ' M = ', size(Aineq, 2), ', Random test ', irand

                call safealloc(x, n)
                x = x0
                call lincoa(noisy_calfun, x, f, cstrv=cstrv, A=Aineq, b=bineq, &
                    & rhobeg=rhobeg, rhoend=rhoend, maxfun=maxfun, maxhist=maxhist, fhist=fhist, &
                    & xhist=xhist, chist=chist, ctol=ctol, ftarget=ftarget, maxfilt=maxfilt, iprint=iprint)

                print *, 'Result: ', f, cstrv, x

                if (prob % probtype == 'u') then  ! Run the test without constraints
                    call safealloc(x_unc, n)
                    x_unc = x0
                    call lincoa(noisy_calfun, x_unc, f_unc, rhobeg=rhobeg, rhoend=rhoend, maxfun=maxfun, &
                        & maxhist=maxhist, fhist=fhist, xhist=xhist, ftarget=ftarget, maxfilt=maxfilt, &
                        & iprint=iprint)
                    print *, 'Result (unconstrained): ', f, cstrv, x
                    call validate(all(abs(x - x_unc) <= 0), 'X == X_UNC', srname)
                    call validate(abs(f - f_unc) <= 0 .or. (is_neginf(f) .and. is_neginf(f_unc)), 'F == F_UNC', srname)
                end if

                deallocate (x)
                nullify (orig_calfun)
            end do

            ! DESTRUCT deallocates allocated arrays/pointers and nullify the pointers. Must be called.
            call destruct(prob)  ! Destruct the testing problem.
        end do
    end do
end if


end subroutine test_solver


end module test_solver_mod
