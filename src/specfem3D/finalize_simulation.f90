!=====================================================================
!
!               S p e c f e m 3 D  V e r s i o n  3 . 0
!               ---------------------------------------
!
!     Main historical authors: Dimitri Komatitsch and Jeroen Tromp
!                              CNRS, France
!                       and Princeton University, USA
!                 (there are currently many more authors!)
!                           (c) October 2017
!
! This program is free software; you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation; either version 3 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License along
! with this program; if not, write to the Free Software Foundation, Inc.,
! 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
!
!=====================================================================
!
! United States and French Government Sponsorship Acknowledged.

  subroutine finalize_simulation()

  use adios_manager_mod
  use specfem_par
  use specfem_par_elastic
  use specfem_par_acoustic
  use specfem_par_poroelastic
  use pml_par
  use gravity_perturbation, only: gravity_output, GRAVITY_SIMULATION

  implicit none

  integer :: ier

  ! write gravity perturbations
  if (GRAVITY_SIMULATION) call gravity_output()

  ! save last frame

  if (SIMULATION_TYPE == 1 .and. SAVE_FORWARD) then
    if (ADIOS_FOR_FORWARD_ARRAYS) then
      call save_forward_arrays_adios()
    else
      open(unit=IOUT,file=prname(1:len_trim(prname))//'save_forward_arrays.bin', &
            status='unknown',form='unformatted',iostat=ier)
      if (ier /= 0) then
        print *,'error: opening save_forward_arrays.bin'
        print *,'path: ',prname(1:len_trim(prname))//'save_forward_arrays.bin'
        call exit_mpi(myrank,'error opening file save_forward_arrays.bin')
      endif

      if (ACOUSTIC_SIMULATION) then
        write(IOUT) potential_acoustic
        write(IOUT) potential_dot_acoustic
        write(IOUT) potential_dot_dot_acoustic
      endif

      if (ELASTIC_SIMULATION) then
        write(IOUT) displ
        write(IOUT) veloc
        write(IOUT) accel

        if (ATTENUATION) then
          write(IOUT) R_trace
          write(IOUT) R_xx
          write(IOUT) R_yy
          write(IOUT) R_xy
          write(IOUT) R_xz
          write(IOUT) R_yz
          write(IOUT) epsilondev_trace
          write(IOUT) epsilondev_xx
          write(IOUT) epsilondev_yy
          write(IOUT) epsilondev_xy
          write(IOUT) epsilondev_xz
          write(IOUT) epsilondev_yz
        endif
      endif

      if (POROELASTIC_SIMULATION) then
        write(IOUT) displs_poroelastic
        write(IOUT) velocs_poroelastic
        write(IOUT) accels_poroelastic
        write(IOUT) displw_poroelastic
        write(IOUT) velocw_poroelastic
        write(IOUT) accelw_poroelastic
      endif

      close(IOUT)
    endif
  endif

  ! adjoint simulations
  if (SIMULATION_TYPE == 3) then
    ! adjoint kernels
    call save_adjoint_kernels()
  endif

  ! seismograms and source parameter gradients for (pure type=2) adjoint simulation runs
  if (SIMULATION_TYPE == 2) then
    if (nrec_local > 0) then
      ! seismograms (strain)
      call write_adj_seismograms2_to_file(myrank,seismograms_eps,number_receiver_global,nrec_local,it,DT,NSTEP,t0)
      ! source gradients  (for sources in elastic domains)
      call save_kernels_source_derivatives()
    endif
  endif

  ! stacey absorbing fields will be reconstructed for adjoint simulations
  ! using snapshot files of wavefields
  if (STACEY_ABSORBING_CONDITIONS) then
    ! closes absorbing wavefield saved/to-be-saved by forward simulations
    if (num_abs_boundary_faces > 0 .and. (SIMULATION_TYPE == 3 .or. &
          (SIMULATION_TYPE == 1 .and. SAVE_FORWARD))) then

      if (ELASTIC_SIMULATION) call close_file_abs(IOABS)
      if (ACOUSTIC_SIMULATION) call close_file_abs(IOABS_AC)

    endif
  endif

  ! mass matrices
  if (ELASTIC_SIMULATION) then
    deallocate(rmassx)
    deallocate(rmassy)
    deallocate(rmassz)
  endif
  if (ACOUSTIC_SIMULATION) then
    deallocate(rmass_acoustic)
  endif

  ! C-PML absorbing boundary conditions
  if (PML_CONDITIONS) then
    ! outputs informations about C-PML elements in VTK-file format
    if (NSPEC_CPML > 0) call pml_output_VTKs()
    ! deallocates C_PML arrays
    call pml_cleanup()
  endif

  ! boundary surfaces
  deallocate(ibelm_xmin)
  deallocate(ibelm_xmax)
  deallocate(ibelm_ymin)
  deallocate(ibelm_ymax)
  deallocate(ibelm_bottom)
  deallocate(ibelm_top)

  ! free arrays
  ! sources
  deallocate(islice_selected_source,ispec_selected_source)
  deallocate(Mxx,Myy,Mzz,Mxy,Mxz,Myz)
  deallocate(xi_source,eta_source,gamma_source)
  deallocate(tshift_src,hdur,hdur_Gaussian)
  deallocate(utm_x_source,utm_y_source)
  deallocate(nu_source)
  deallocate(user_source_time_function)
  ! receivers
  deallocate(islice_selected_rec,ispec_selected_rec)
  deallocate(xi_receiver,eta_receiver,gamma_receiver)
  deallocate(station_name,network_name)
  deallocate(nu)
  deallocate(pm1_source_encoding)
  deallocate(sourcearrays)
  if (SIMULATION_TYPE == 2 .or. SIMULATION_TYPE == 3) deallocate(source_adjoint)
  ! receiver arrays
  deallocate(number_receiver_global)
  deallocate(hxir_store,hetar_store,hgammar_store)
  if (SIMULATION_TYPE == 2) deallocate(hpxir_store,hpetar_store,hpgammar_store)
  ! adjoint sources
  if (SIMULATION_TYPE == 2 .or. SIMULATION_TYPE == 3) then
    if (SIMULATION_TYPE == 2) then
      deallocate(number_adjsources_global)
      deallocate(hxir_adjstore,hetar_adjstore,hgammar_adjstore)
    else
      nullify(number_adjsources_global)
      nullify(hxir_adjstore,hetar_adjstore,hgammar_adjstore)
    endif
  endif
  ! seismograms
  deallocate(seismograms_d,seismograms_v,seismograms_a,seismograms_p)
  if (SIMULATION_TYPE == 2) deallocate(seismograms_eps)
  ! moment tensor derivatives
  if (nrec_local > 0 .and. SIMULATION_TYPE == 2) deallocate(Mxx_der,Myy_der,Mzz_der,Mxy_der,Mxz_der,Myz_der,sloc_der)


  ! ADIOS file i/o
  if (ADIOS_ENABLED) then
    call adios_cleanup()
  endif

  ! asdf finalizes
  if ((SIMULATION_TYPE == 2 .or. SIMULATION_TYPE == 3) .and. READ_ADJSRC_ASDF) then
    call asdf_cleanup()
  endif

  ! close the main output file
  if (myrank == 0) then
    write(IMAIN,*)
    write(IMAIN,*) 'End of the simulation'
    write(IMAIN,*)
    close(IMAIN)
  endif

  ! synchronize all the processes to make sure everybody has finished
  call synchronize_all()

  end subroutine finalize_simulation
