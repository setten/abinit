!{\src2tex{textfont=tt}}
!!****f* ABINIT/stress
!!
!! NAME
!! stress
!!
!! FUNCTION
!! Compute the stress tensor
!! strten(i,j) = (1/ucvol)*d(Etot)/(d(eps(i,j)))
!! where Etot is energy per unit cell, ucvol is the unstrained unit cell
!! volume, r(i,iat) is the ith position of atom iat,
!! and eps(i,j) is an infinitesimal strain which maps each
!! point r to r(i) -> r(i) + Sum(j) [eps(i,j)*r(j)].
!!
!! COPYRIGHT
!! Copyright (C) 1998-2017 ABINIT group (DCA, XG, GMR, FJ, MT)
!! This file is distributed under the terms of the
!! GNU General Public License, see ~abinit/COPYING
!! or http://www.gnu.org/copyleft/gpl.txt .
!! For the initials of contributors, see ~abinit/doc/developers/contributors.txt.
!!
!! INPUTS
!!  atindx1(natom)=index table for atoms, inverse of atindx
!! berryopt    =  4/14: electric field is on -> add the contribution of the
!!                      -ebar_i p_i - Omega/(8*pi) (g^{-1})_ij ebar_i ebar_j  terms to the total energy
!!     = 6/16, or 7/17: electric displacement field is on  -> add the contribution of the
!!                      Omega/(8*pi) (g^{-1})_ij ebar_i ebar_j  terms to the total energy
!!   from Etot(npw) data (at fixed geometry), used for making
!!   Pulay correction to stress tensor (hartree).  Should be <=0.
!!  dtefield <type(efield_type)> = variables related to Berry phase
!!  eei=local pseudopotential part of Etot (hartree)
!!  efield = cartesian coordinates of the electric field in atomic units
!!  ehart=Hartree energy (hartree)
!!  eii=pseudoion core correction energy part of Etot (hartree)
!!  fock <type(fock_type)>= quantities to calculate Fock exact exchange
!!  gsqcut=cutoff value on G**2 for (large) sphere inside FFT box.
!!                       gsqcut=(boxcut**2)*ecut/(2._dp*(Pi**2)
!!  ixc = choice of exchange-correlation functional
!!  kinstr(6)=kinetic energy part of stress tensor
!!  mgfft=maximum size of 1D FFTs
!!  mpi_enreg=informations about MPI parallelization
!!  mqgrid=dimensioned number of q grid points for local psp spline
!!  n1xccc=dimension of xccc1d ; 0 if no XC core correction is used
!!  n3xccc=dimension of the xccc3d array (0 or nfft).
!!  natom=number of atoms in cell
!!  nattyp(ntypat)=number of atoms of each type
!!  nfft=(effective) number of FFT grid points (for this processor)
!!  ngfft(18)=contain all needed information about 3D FFT, see ~abinit/doc/input_variables/vargs.htm#ngfft
!!  nlstr(6)=nonlocal part of stress tensor
!!  nspden=number of spin-density components
!!  nsym=number of symmetries in space group
!!  ntypat=number of types of atoms
!!  psps <type(pseudopotential_type)>=variables related to pseudopotentials
!!  pawtab(ntypat*usepaw) <type(pawtab_type)>=paw tabulated starting data
!!  ph1d(2,3*(2*mgfft+1)*natom)=1-dim phase (structure factor) array
!!  prtvol=integer controlling volume of printed output
!!  qgrid(mqgrid)=q point array for local psp spline fits
!!  red_efieldbar(3) = efield in reduced units relative to reciprocal lattice
!!  rhog(2,nfft)=Fourier transform of charge density (bohr^-3)
!!  rprimd(3,3)=dimensional primitive translations in real space (bohr)
!!  strsxc(6)=xc correction to stress
!!  symrec(3,3,nsym)=symmetries in reciprocal space, reduced coordinates
!!  typat(natom)=type integer for each atom in cell
!!  usefock=1 if fock operator is used; 0 otherwise.
!!  usepaw= 0 for non paw calculation; =1 for paw calculation
!!  vdw_tol= Van der Waals tolerance
!!  vdw_tol_3bt= Van der Waals tolerance on the 3-body term (only effective
!!               vdw_xc=6)
!!  vdw_xc= Van der Waals correction flag
!!  vlspl(mqgrid,2,ntypat)=local psp spline
!!  vxc(nfft,nspden)=exchange-correlation potential (hartree) in real space
!!  xccc1d(n1xccc*(1-usepaw),6,ntypat)=1D core charge function and five derivatives,
!!                          for each type of atom, from psp (used in Norm-conserving only)
!!  xccc3d(n3xccc)=3D core electron density for XC core correction, bohr^-3
!!  xcccrc(ntypat)=XC core correction cutoff radius (bohr) for each atom type
!!  xred(3,natom)=reduced dimensionless atomic coordinates
!!  zion(ntypat)=valence charge of each type of atom
!!  znucl(ntypat)=atomic number of atom type
!!
!! OUTPUT
!!  strten(6)=components of the stress tensor (hartree/bohr^3) for the
!!    6 unique components of this symmetric 3x3 tensor:
!!    Given in order (1,1), (2,2), (3,3), (3,2), (3,1), (2,1).
!!    The diagonal components of the returned stress tensor are
!!    CORRECTED for the Pulay stress.
!!
!! SIDE EFFECTS
!!  electronpositron <type(electronpositron_type)>=quantities for the electron-positron annihilation (optional argument)
!!
!! NOTES
!! * Concerning the stress tensor:
!!   See O. H. Nielsen and R. M. Martin, PRB 32, 3792 (1985).
!!   Note that first term in equation (2) should have minus sign
!!   (for kinetic energy contribution to stress tensor).
!!   Normalizations in this code differ somewhat from those employed
!!   by Nielsen and Martin.
!!   For the stress tensor contribution from the nonlocal Kleinman-Bylander
!!   separable pseudopotential, see D. M. Bylander, L. Kleinman, and
!!   S. Lee, PRB 42, 1394 (1990).
!!   Again normalization conventions differ somewhat.
!!   See Doug Allan s notes starting page 795 (13 Jan 1992).
!! * This subroutine calls different subroutines to compute the stress
!!   tensor contributions from the following parts of the total energy:
!!   (1) kinetic energy, (2) exchange-correlation energy,
!!   (3) Hartree energy, (4) local pseudopotential energy,
!!   (5) pseudoion core correction energy, (6) nonlocal pseudopotential energy,
!!   (7) Ewald energy.
!!
!! PARENTS
!!      forstr
!!
!! CHILDREN
!!      atm2fft,ewald2,fourdp,metric,mkcore,mklocl_recipspace,stresssym,strhar
!!      timab,vdw_dftd2,vdw_dftd3,wrtout,zerosym
!!
!! SOURCE

#if defined HAVE_CONFIG_H
#include "config.h"
#endif

#include "abi_common.h"

 subroutine stress(atindx1,berryopt,dtefield,eei,efield,ehart,eii,fock,gsqcut,ixc,kinstr,&
&                  mgfft,mpi_enreg,mqgrid,n1xccc,n3xccc,natom,nattyp,&
&                  nfft,ngfft,nlstr,nspden,nsym,ntypat,paral_kgb,psps,pawtab,ph1d,&
&                  prtvol,qgrid,red_efieldbar,rhog,rprimd,strten,strsxc,symrec,&
&                  typat,usefock,usepaw,vdw_tol,vdw_tol_3bt,vdw_xc,&
&                  vlspl,vxc,xccc1d,xccc3d,xcccrc,xred,zion,znucl,qvpotzero,&
&                  electronpositron) ! optional argument

 use defs_basis
 use defs_abitypes
 use m_efield
 use m_profiling_abi
 use m_errors

 use m_fock,             only : fock_type
 use m_ewald,            only : ewald2
 use defs_datatypes,     only : pseudopotential_type
 use m_pawtab,           only : pawtab_type
 use m_electronpositron, only : electronpositron_type,electronpositron_calctype

!This section has been created automatically by the script Abilint (TD).
!Do not modify the following lines by hand.
#undef ABI_FUNC
#define ABI_FUNC 'stress'
 use interfaces_14_hidewrite
 use interfaces_18_timing
 use interfaces_41_geometry
 use interfaces_53_ffts
 use interfaces_56_xc
 use interfaces_64_psp
 use interfaces_67_common, except_this_one => stress
!End of the abilint section

 implicit none

!Arguments ------------------------------------
!scalars
 integer,intent(in) :: berryopt,ixc,mgfft,mqgrid,n1xccc,n3xccc,natom,nfft,nspden
 integer,intent(in) :: nsym,ntypat,paral_kgb,prtvol,usefock,usepaw,vdw_xc
 real(dp),intent(in) :: eei,ehart,eii,gsqcut,vdw_tol,vdw_tol_3bt,qvpotzero
 type(efield_type),intent(in) :: dtefield
 type(pseudopotential_type),intent(in) :: psps
 type(electronpositron_type),pointer,optional :: electronpositron
 type(MPI_type),intent(in) :: mpi_enreg
 type(fock_type),pointer, intent(inout) :: fock
!arrays
 integer,intent(in) :: atindx1(natom),nattyp(ntypat),ngfft(18),symrec(3,3,nsym)
 integer,intent(in) :: typat(natom)
 real(dp),intent(in) :: efield(3),kinstr(6),nlstr(6)
 real(dp),intent(in) :: ph1d(2,3*(2*mgfft+1)*natom),qgrid(mqgrid)
 real(dp),intent(in) :: red_efieldbar(3),rhog(2,nfft),rprimd(3,3),strsxc(6)
 real(dp),intent(in) :: vlspl(mqgrid,2,ntypat),vxc(nfft,nspden)
 real(dp),intent(in) :: xccc1d(n1xccc*(1-usepaw),6,ntypat),xcccrc(ntypat)
 real(dp),intent(in) :: xred(3,natom),zion(ntypat),znucl(ntypat)
 real(dp),intent(inout) :: xccc3d(n3xccc)
 real(dp),intent(out) :: strten(6)
 type(pawtab_type),intent(in) :: pawtab(ntypat*usepaw)

!Local variables-------------------------------
!scalars
 integer :: iatom,idir,ii,ipositron,mu,optatm,optdyfr,opteltfr,optgr,option
 integer :: optn,optn2,optstr,optv,sdir
 real(dp),parameter :: tol=1.0d-15
 real(dp) :: e_dum,strsii,ucvol,vol_element
 character(len=500) :: message
 logical :: calc_epaw3_stress, efield_flag
!arrays
 integer :: qprtrb_dum(3)
 real(dp) :: corstr(6),ep3(3),epaws3red(6),ewestr(6),gmet(3,3)
!Maxwell-stress constribution, and magnitude of efield
 real(dp) :: Maxstr(6),ModE
 real(dp) :: gprimd(3,3),harstr(6),lpsstr(6),rmet(3,3),tsec(2),uncorr(3)
 real(dp) :: vdwstr(6),vprtrb_dum(2)
 real(dp) :: dummy_in(0)
 real(dp) :: dummy_out1(0),dummy_out2(0),dummy_out3(0),dummy_out4(0),dummy_out5(0),dummy_out6(0),dummy_out7(0) 
 real(dp),allocatable :: dummy(:),dyfr_dum(:,:,:),gr_dum(:,:),rhog_ep(:,:),v_dum(:)
 real(dp),allocatable :: vxctotg(:,:)
 character(len=10) :: EPName(1:2)=(/"Electronic","Positronic"/)

! *************************************************************************

 call timab(37,1,tsec)

!Compute different geometric tensor, as well as ucvol, from rprimd
 call metric(gmet,gprimd,-1,rmet,rprimd,ucvol)

!=======================================================================
!========= Local pseudopotential and core charge contributions =========
!=======================================================================

 if (usepaw==1 .or. psps%nc_xccc_gspace==1) then

!  PAW or NC with nc_xccc_gspace: compute local psp and core charge contribs together in reciprocal space
   call timab(551,1,tsec)
   if (n3xccc>0) then
     ABI_ALLOCATE(v_dum,(nfft))
     ABI_ALLOCATE(vxctotg,(2,nfft))
     v_dum(:)=vxc(:,1);if (nspden>=2) v_dum(:)=0.5_dp*(v_dum(:)+vxc(:,2))
     call fourdp(1,vxctotg,v_dum,-1,mpi_enreg,nfft,ngfft,paral_kgb,0)
     call zerosym(vxctotg,2,ngfft(1),ngfft(2),ngfft(3),&
&     comm_fft=mpi_enreg%comm_fft,distribfft=mpi_enreg%distribfft)
     ABI_DEALLOCATE(v_dum)
   else
     ABI_ALLOCATE(vxctotg,(0,0))
   end if

   optatm=0;optdyfr=0;opteltfr=0;optgr=0;optstr=1;optv=1;optn=n3xccc/nfft;optn2=1;

   call atm2fft(atindx1,dummy_out1,dummy_out2,dummy_out3,dummy_out4,&
&   dummy_out5,dummy_in,gmet,gprimd,dummy_out6,dummy_out7,gsqcut,&
&   mgfft,mqgrid,natom,nattyp,nfft,ngfft,ntypat,optatm,optdyfr,opteltfr,optgr,optn,optn2,optstr,optv,&
&   psps,pawtab,ph1d,qgrid,qprtrb_dum,rhog,corstr,lpsstr,ucvol,usepaw,vxctotg,vxctotg,vxctotg,vprtrb_dum,vlspl,&
&   comm_fft=mpi_enreg%comm_fft,me_g0=mpi_enreg%me_g0,&
&   paral_kgb=mpi_enreg%paral_kgb,distribfft=mpi_enreg%distribfft)

   !if (n3xccc>0)  then
   ABI_DEALLOCATE(vxctotg)
   !end if
   if (n3xccc==0) corstr=zero
   call timab(551,2,tsec)

 else

!  Norm-conserving: compute local psp contribution in reciprocal space
!  and core charge contribution in real space
   option=3
   ABI_ALLOCATE(dyfr_dum,(3,3,natom))
   ABI_ALLOCATE(gr_dum,(3,natom))
   ABI_ALLOCATE(v_dum,(nfft))
   call mklocl_recipspace(dyfr_dum,eei,gmet,gprimd,gr_dum,gsqcut,lpsstr,mgfft,&
&   mpi_enreg,mqgrid,natom,nattyp,nfft,ngfft,ntypat,option,paral_kgb,ph1d,qgrid,&
&   qprtrb_dum,rhog,ucvol,vlspl,vprtrb_dum,v_dum)
   if (n3xccc>0) then
     call timab(55,1,tsec)
     call mkcore(corstr,dyfr_dum,gr_dum,mpi_enreg,natom,nfft,nspden,ntypat,ngfft(1),&
&     n1xccc,ngfft(2),ngfft(3),option,rprimd,typat,ucvol,vxc,&
&     xcccrc,xccc1d,xccc3d,xred)
     call timab(55,2,tsec)
   else
     corstr(:)=zero
   end if
   ABI_DEALLOCATE(dyfr_dum)
   ABI_DEALLOCATE(gr_dum)
   ABI_DEALLOCATE(v_dum)
 end if

!=======================================================================
!======================= Hartree energy contribution ===================
!=======================================================================

 call strhar(ehart,gprimd,gsqcut,harstr,mpi_enreg,nfft,ngfft,rhog,ucvol)

!=======================================================================
!======================= Ewald contribution ============================
!=======================================================================

 call timab(38,1,tsec)
 call ewald2(gmet,natom,ntypat,rmet,rprimd,ewestr,typat,ucvol,xred,zion)

!=======================================================================
!================== VdW DFT-D contribution ============================
!=======================================================================

 if (vdw_xc==5) then
   call vdw_dftd2(e_dum,ixc,natom,ntypat,0,typat,rprimd,vdw_tol,&
&   xred,znucl,str_vdw_dftd2=vdwstr)
 elseif (vdw_xc==6.or.vdw_xc==7) then
   call vdw_dftd3(e_dum,ixc,natom,ntypat,0,typat,rprimd,vdw_xc,&
&   vdw_tol,vdw_tol_3bt,xred,znucl,str_vdw_dftd3=vdwstr) 
 end if

 call timab(38,2,tsec)

!HONG  no Berry phase contribution if using reduced ebar or d according to
!HONG  (PRL 89, 117602 (2002)   Nature Physics: M. Stengel et.al. (2009))
!=======================================================================
!=================== Berry phase contribution ==========================
!=======================================================================

!if (berryopt==4) then
!berrystr_tmp(:,:) = zero
!Diagonal:
!do mu = 1, 3
!do ii = 1, 3
!berrystr_tmp(mu,mu) = berrystr_tmp(mu,mu) - &
!&       efield(mu)*rprimd(mu,ii)*(pel(ii) + pion(ii))/ucvol
!end do
!end do
!Off-diagonal (symmetrized before adding it to strten):
!do ii = 1, 3
!berrystr_tmp(3,2) = berrystr_tmp(3,2) &
!&     - efield(3)*rprimd(2,ii)*(pel(ii) + pion(ii))/ucvol
!berrystr_tmp(2,3) = berrystr_tmp(2,3) &
!&     - efield(2)*rprimd(3,ii)*(pel(ii) + pion(ii))/ucvol
!berrystr_tmp(3,1) = berrystr_tmp(3,1) &
!&     - efield(3)*rprimd(1,ii)*(pel(ii) + pion(ii))/ucvol
!berrystr_tmp(1,3) = berrystr_tmp(1,3) &
!&     - efield(1)*rprimd(3,ii)*(pel(ii) + pion(ii))/ucvol
!berrystr_tmp(2,1) = berrystr_tmp(2,1) &
!&     - efield(2)*rprimd(1,ii)*(pel(ii) + pion(ii))/ucvol
!berrystr_tmp(1,2) = berrystr_tmp(1,2) &
!&     - efield(1)*rprimd(2,ii)*(pel(ii) + pion(ii))/ucvol
!end do
!berrystr(1) = berrystr_tmp(1,1)
!berrystr(2) = berrystr_tmp(2,2)
!berrystr(3) = berrystr_tmp(3,3)
!berrystr(4) = (berrystr_tmp(3,2) + berrystr_tmp(2,3))/two
!berrystr(5) = (berrystr_tmp(3,1) + berrystr_tmp(1,3))/two
!berrystr(6) = (berrystr_tmp(2,1) + berrystr_tmp(1,2))/two
!end if

!=======================================================================
!================= Other (trivial) contributions =======================
!=======================================================================

!Nonlocal part of stress has already been computed
!(in forstrnps(norm-conserving) or pawgrnl(PAW))

!Kinetic part of stress has already been computed
!(in forstrnps)

!XC part of stress tensor has already been computed in "strsxc"

!ii part of stress (diagonal) is trivial!
 strsii=-eii/ucvol 
!qvpotzero is non zero, only when usepotzero=1
 strsii=strsii+qvpotzero/ucvol

!======================================================================
!HONG  Maxwell stress when electric/displacement field is non-zero=====
!======================================================================
 efield_flag = (berryopt==4 .or. berryopt==6 .or. berryopt==7 .or. &
& berryopt==14 .or. berryopt==16 .or. berryopt==17)
 calc_epaw3_stress = (efield_flag .and. usepaw == 1)
 if ( efield_flag ) then
   ModE=dot_product(efield,efield)
   do ii=1,3
     Maxstr(ii)=two*efield(ii)*efield(ii)-ModE
   end do
   Maxstr(4)=two*efield(3)*efield(2)
   Maxstr(5)=two*efield(3)*efield(1)
   Maxstr(6)=two*efield(2)*efield(1)
!  Converting to units of Ha/Bohr^3
!  Maxstr(:)=Maxstr(:)*e_Cb*Bohr_Ang*1.0d-10/(Ha_J*8.0d0*pi)

   Maxstr(:)=Maxstr(:)*eps0*Ha_J*Bohr_Ang*1.0d-10/(8.0d0*pi*e_Cb**2)

   write(message, '(a,a)' )ch10,&
&   ' Cartesian components of Maxwell stress tensor (hartree/bohr^3)'
   call wrtout(ab_out,message,'COLL')
   call wrtout(std_out,  message,'COLL')
   write(message, '(a,1p,e16.8,a,1p,e16.8)' ) &
&   ' Maxstr(1 1)=',Maxstr(1),' Maxstr(3 2)=',Maxstr(4)
   call wrtout(ab_out,message,'COLL')
   call wrtout(std_out,  message,'COLL')
   write(message, '(a,1p,e16.8,a,1p,e16.8)' ) &
&   ' Maxstr(2 2)=',Maxstr(2),' Maxstr(3 1)=',Maxstr(5)
   call wrtout(ab_out,message,'COLL')
   call wrtout(std_out,  message,'COLL')
   write(message, '(a,1p,e16.8,a,1p,e16.8)' ) &
&   ' Maxstr(3 3)=',Maxstr(3),' Maxstr(2 1)=',Maxstr(6)
   call wrtout(ab_out,message,'COLL')
   call wrtout(std_out,  message,'COLL')
   write(message, '(a)' ) ' '
   call wrtout(ab_out,message,'COLL')
   call wrtout(std_out,  message,'COLL')

 end if

! compute additional F3-type stress due to projectors for electric field with PAW
 if ( efield_flag .and. calc_epaw3_stress ) then  
   do sdir = 1, 6
     ep3(:) = zero
     do idir = 1, 3
       vol_element=one/(ucvol*dtefield%nstr(idir)*dtefield%nkstr(idir))
       do iatom = 1, natom
         ep3(idir) = ep3(idir) + vol_element*dtefield%epaws3(iatom,idir,sdir)
       end do ! end loop over atoms
     end do ! end loop over idir (components of P)
! note no appearance of ucvol here unlike in forces, stress definition includes
! division by ucvol, which cancels the factor in -ucvol e . p
     epaws3red(sdir) = -dot_product(red_efieldbar(1:3),ep3(1:3))
   end do

!   write(message, '(a,a)' )ch10,&
!&   ' Cartesian components of PAW sigma_3 stress tensor (hartree/bohr^3)'
!   call wrtout(ab_out,message,'COLL')
!   call wrtout(std_out,  message,'COLL')
!   write(message, '(a,1p,e16.8,a,1p,e16.8)' ) &
!&   ' epaws3red(1 1)=',epaws3red(1),' epaws3red(3 2)=',epaws3red(4)
!   call wrtout(ab_out,message,'COLL')
!   call wrtout(std_out,  message,'COLL')
!   write(message, '(a,1p,e16.8,a,1p,e16.8)' ) &
!&   ' epaws3red(2 2)=',epaws3red(2),' epaws3red(3 1)=',epaws3red(5)
!   call wrtout(ab_out,message,'COLL')
!   call wrtout(std_out,  message,'COLL')
!   write(message, '(a,1p,e16.8,a,1p,e16.8)' ) &
!&   ' epaws3red(3 3)=',epaws3red(3),' epaws3red(2 1)=',epaws3red(6)
!   call wrtout(ab_out,message,'COLL')
!   call wrtout(std_out,  message,'COLL')
!   write(message, '(a)' ) ' '
!   call wrtout(ab_out,message,'COLL')
!   call wrtout(std_out,  message,'COLL')

 end if

!=======================================================================
!===== Assemble the various contributions to the stress tensor =========
!=======================================================================
!In cartesian coordinates (symmetric storage) 

 strten(:)=kinstr(:)+ewestr(:)+corstr(:)+strsxc(:)+harstr(:)+lpsstr(:)+nlstr(:)

 if (usefock==1 .and. associated(fock).and.fock%optstr) then
   strten(:)=strten(:)+fock%stress(:)
 end if
!Add contributions for constant E or D calculation.
 if ( efield_flag ) then
   strten(:)=strten(:)+Maxstr(:)
   if ( calc_epaw3_stress ) strten(:) = strten(:) + epaws3red(:) 
 end if
 if (vdw_xc>=5.and.vdw_xc<=7) strten(:)=strten(:)+vdwstr(:)

!Additional stuff for electron-positron
 ipositron=0
 if (present(electronpositron)) then
   if (associated(electronpositron)) then
     if (allocated(electronpositron%stress_ep)) ipositron=electronpositron_calctype(electronpositron) 
   end if
 end if
 if (abs(ipositron)==1) then
   strten(:)=strten(:)-harstr(:)-ewestr(:)-corstr(:)-lpsstr(:)
   harstr(:)=zero;ewestr(:)=zero;corstr(:)=zero;strsii=zero
   lpsstr(:)=-lpsstr(:);lpsstr(1:3)=lpsstr(1:3)-two*eei/ucvol
   strten(:)=strten(:)+lpsstr(:)
   if (vdw_xc>=5.and.vdw_xc<=7) strten(:)=strten(:)-vdwstr(:)
   if (vdw_xc>=5.and.vdw_xc<=7) vdwstr(:)=zero
 end if
 if (abs(ipositron)==2) then
   ABI_ALLOCATE(rhog_ep,(2,nfft))
   ABI_ALLOCATE(dummy,(6))
   call fourdp(1,rhog_ep,electronpositron%rhor_ep,-1,mpi_enreg,nfft,ngfft,paral_kgb,0)
   rhog_ep=-rhog_ep
   call strhar(electronpositron%e_hartree,gprimd,gsqcut,dummy,mpi_enreg,nfft,ngfft,rhog_ep,ucvol)
   strten(:)=strten(:)+dummy(:);harstr(:)=harstr(:)+dummy(:)
   ABI_DEALLOCATE(rhog_ep)
   ABI_DEALLOCATE(dummy)
 end if
 if (ipositron>0) strten(:)=strten(:)+electronpositron%stress_ep(:)

!Symmetrize resulting tensor if nsym>1
 if (nsym>1) then
   call stresssym(gprimd,nsym,strten,symrec)
 end if

!Set to zero very small values of stress
 do mu=1,6
   if (abs(strten(mu))<tol) strten(mu)=zero
 end do

!Include diagonal terms, save uncorrected stress for output
 do mu=1,3
   uncorr(mu)=strten(mu)+strsii
   strten(mu)=uncorr(mu)
 end do

!=======================================================================
!================ Print out info about stress tensor ===================
!=======================================================================
 if (prtvol>=10.and.ipositron>=0) then
   write(message, '(a)' ) ' '
   call wrtout(std_out,message,'COLL')
   do mu=1,6
     write(message, '(a,i5,a,1p,e22.12)' )&
&     ' stress: component',mu,' of hartree stress is',harstr(mu)
     call wrtout(std_out,message,'COLL')
   end do
   write(message, '(a)' ) ' '
   call wrtout(std_out,message,'COLL')
   do mu=1,6
     write(message, '(a,i5,a,1p,e22.12)' )&
&     ' stress: component',mu,' of loc psp stress is',lpsstr(mu)
     call wrtout(std_out,message,'COLL')
   end do
   write(message, '(a)' ) ' '
   call wrtout(std_out,message,'COLL')
   do mu=1,6
     write(message, '(a,i5,a,1p,e22.12)' )&
&     ' stress: component',mu,&
&     ' of kinetic stress is',kinstr(mu)
     call wrtout(std_out,message,'COLL')
   end do
   write(message, '(a)' ) ' '
   call wrtout(std_out,message,'COLL')
   do mu=1,6
     write(message, '(a,i5,a,1p,e22.12)' )&
&     ' stress: component',mu,' of nonlocal ps stress is',nlstr(mu)
     call wrtout(std_out,message,'COLL')
   end do
   write(message, '(a)' ) ' '
   call wrtout(std_out,message,'COLL')
   do mu=1,6
     write(message, '(a,i5,a,1p,e22.12)' )&
&     ' stress: component',mu,' of     core xc stress is',corstr(mu)
     call wrtout(std_out,message,'COLL')
   end do
   write(message, '(a)' ) ' '
   call wrtout(std_out,message,'COLL')
   do mu=1,6
     write(message, '(a,i5,a,1p,e22.12)' )&
&     ' stress: component',mu,&
&     ' of Ewald energ stress is',ewestr(mu)
     call wrtout(std_out,message,'COLL')
   end do
   write(message, '(a)' ) ' '
   call wrtout(std_out,message,'COLL')
   do mu=1,6
     write(message, '(a,i5,a,1p,e22.12)' ) &
&     ' stress: component',mu,' of xc stress is',strsxc(mu)
     call wrtout(std_out,message,'COLL')
   end do
   if (vdw_xc>=5.and.vdw_xc<=7) then
     write(message, '(a)' ) ' '
     call wrtout(std_out,message,'COLL')
     do mu=1,6
       write(message, '(a,i5,a,1p,e22.12)' )&
&       ' stress: component',mu,&
&       ' of VdW DFT-D stress is',vdwstr(mu)
       call wrtout(std_out,message,'COLL')
     end do
   end if
   write(message, '(a)' ) ' '
   call wrtout(std_out,message,'COLL')
   write(message, '(a,1p,e22.12)' ) &
&   ' stress: ii (diagonal) part is',strsii
   call wrtout(std_out,message,'COLL')
   if (berryopt==4 .or. berryopt==6 .or. berryopt==7 .or.  &
&   berryopt==14 .or. berryopt==16 .or. berryopt==17) then  !!HONG
     write(message, '(a)' ) ' '
     call wrtout(std_out,message,'COLL')
     do mu = 1, 6
       write(message, '(a,i2,a,1p,e22.12)' )&
&       ' stress: component',mu,' of Maxwell stress is',&
&       Maxstr(mu)
       call wrtout(std_out,message,'COLL')
     end do
   end if
   if (ipositron/=0) then
     write(message, '(a)' ) ' '
     call wrtout(std_out,message,'COLL')
     do mu=1,6
       write(message, '(a,i5,3a,1p,e22.12)' ) &
&       ' stress: component',mu,' of ',EPName(abs(ipositron)), &
&       ' stress is',electronpositron%stress_ep(mu)
       call wrtout(std_out,message,'COLL')
     end do
   end if

 end if ! prtvol
 if (ipositron>=0) then
   write(message, '(a,a)' )ch10,&
&   ' Cartesian components of stress tensor (hartree/bohr^3)'
   call wrtout(ab_out,message,'COLL')
   call wrtout(std_out,  message,'COLL')
   write(message, '(a,1p,e16.8,a,1p,e16.8)' ) &
&   '  sigma(1 1)=',strten(1),'  sigma(3 2)=',strten(4)
   call wrtout(ab_out,message,'COLL')
   call wrtout(std_out,  message,'COLL')
   write(message, '(a,1p,e16.8,a,1p,e16.8)' ) &
&   '  sigma(2 2)=',strten(2),'  sigma(3 1)=',strten(5)
   call wrtout(ab_out,message,'COLL')
   call wrtout(std_out,  message,'COLL')
   write(message, '(a,1p,e16.8,a,1p,e16.8)' ) &
&   '  sigma(3 3)=',strten(3),'  sigma(2 1)=',strten(6)
   call wrtout(ab_out,message,'COLL')
   call wrtout(std_out,  message,'COLL')
   write(message, '(a)' ) ' '
   call wrtout(ab_out,message,'COLL')
   call wrtout(std_out,  message,'COLL')
 end if
 call timab(37,2,tsec)

end subroutine stress
!!***
